# relibc: posix_spawn leaves close-on-exec descriptors open in the child

Against relibc master 69bb008af1 (the current head).

**Symptom.** A child started with `posix_spawn` keeps every descriptor that is close-on-exec in the parent. Example: the parent creates a pipe (both ends FD_CLOEXEC), spawns `cat` with the read end dup2'ed onto its stdin, writes a line and closes its own write end. `cat` never sees EOF and never exits, because the child still has its own copy of the pipe's write end. (fork+exec, where the kernel's exec does the closing, behaves correctly.)

**Cause.** `Sys::spawn` builds the list of close-on-exec descriptors from the *parent's* table after the child's copy of the table was made, and sends the whole list to the filetable `Close` verb in one call. In the kernel, `Context::bulk_remove_files` validates all handles first ("avoid partial results") and removes nothing if one is missing. The list always contains entries the child's table does not have (the executable's fd and `cur_filetable_fd`, which spawn opens after the copy, and any descriptor another thread opens meanwhile), so the call fails with EBADF, the error is discarded (`let _ =`), and no close-on-exec descriptor is closed in the child.

**Fix.** Close the descriptors with one `Close` call each and ignore the missing ones.

Related upstream items found: issue #192 "Implement posix_spawn" (open, general); MR !1636 "Fix double close on posix_spawn" (merged, before the pinned base, unrelated). No existing issue or MR about close-on-exec descriptors leaking into spawned children.

**Reproducer** (`x26_spawn_cloexec_c`, pure C, builds with `redoxer cc -pthread`):

```c
/* relibc posix_spawn: are the parent's close-on-exec descriptors closed in the
 * child? The parent makes a pipe (both ends FD_CLOEXEC), spawns `cat` with the
 * read end dup2'ed onto its stdin, writes a line, closes its own write end, and
 * expects `cat` to see EOF and exit. If the child kept a copy of the write end
 * (open in its own table), cat never sees EOF and hangs. Same test with fork+exec
 * as the control. */
#include <fcntl.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static int run(int use_spawn) {
    int fds[2];
    if (pipe(fds)) return -1;
    fcntl(fds[0], F_SETFD, FD_CLOEXEC);
    fcntl(fds[1], F_SETFD, FD_CLOEXEC);
    pid_t p = 0;
    char *av[] = {"cat", 0};
    if (use_spawn) {
        posix_spawn_file_actions_t fa;
        posix_spawn_file_actions_init(&fa);
        posix_spawn_file_actions_adddup2(&fa, fds[0], 0);
        int e = posix_spawn(&p, "/usr/bin/cat", &fa, 0, av, environ);
        posix_spawn_file_actions_destroy(&fa);
        if (e) { printf("posix_spawn error %d\n", e); return -1; }
    } else {
        p = fork();
        if (p == 0) { dup2(fds[0], 0); execv("/usr/bin/cat", av); _exit(99); }
    }
    const char *msg = "hello through cat\n";
    write(fds[1], msg, strlen(msg));
    close(fds[1]);
    close(fds[0]);
    int st = 0;
    for (int i = 0; i < 150; i++) {
        pid_t r = waitpid(p, &st, WNOHANG);
        if (r == p) return 0;
        usleep(20000);
    }
    kill(p, 9);
    waitpid(p, &st, 0);
    return 1;   /* cat never saw EOF */
}

int main(void) {
    int rf = run(0), rs = run(1);
    printf("fork+exec: %s; posix_spawn: %s\n", rf == 0 ? "cat exited" : "cat HUNG", rs == 0 ? "cat exited" : "cat HUNG");
    printf("%s x26_spawn_cloexec_c\n", rf == 0 && rs == 0 ? "OK" : "FAIL");
    _exit(0);
}
```

**Verification** (relibc built in CI unpatched/patched in the redoxer environment, the repro linked against each build's libc.so as its ELF interpreter, run under QEMU+KVM):
x26_spawn_cloexec_c: unpatched 4/4 runs FAIL (`cat HUNG`), patched 4/4 runs OK (`cat exited`).
Runs: https://github.com/unxed/go/actions/runs/35427587571 and https://github.com/unxed/go/actions/runs/35428002403 (workflow `redox-relibc-patches`).
