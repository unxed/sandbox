# relibc: posix_spawn fails with EMFILE ("Too many open files") when other threads use descriptors at the same time

Against relibc master 69bb008af1 (the current head).

**Symptom.** With several threads that open/close descriptors (and spawn), `posix_spawn` fails with `EMFILE` although the process has only a handful of descriptors open, sometimes for every spawn of a round. A failed spawn also leaves a half-built child process behind (relibc has already created it), holding copies of the parent's descriptors.

**Cause.** `Sys::spawn` takes a snapshot of the parent's file table for the child (`dup_into_upper(b"copy")`) and then keeps allocating descriptors in the parent (`filetable-binary`, the executable, ...), handing some of them to the child by inserting them at the *same index* (`new_file_table.call_wo(<its own fd>, FD | FD_CLONE)`, and the same for `cwd_fd`). The kernel table is a radix table with an allocated size; inserting beyond it returns EMFILE. The child's snapshot has only the size the parent's table had when it was taken. When another thread uses upper-table slots at the same time (every `open()` takes and frees one), the lowest free index for spawn's own descriptors is higher than that size and the handover fails.

(The failing call was found with a diagnostic build printing errno, fd number, userspace/kernel view of the fd: `errno=24 fd=0x4000000000000055 userspace_has=true kernel_fpath=Ok fstat=Ok`, i.e. the descriptor is fine, the child's table is too small.)

**Fix.** Before the handover, grow the child's upper table (`FileTableVerb::Resize` on the `filetable-binary` handle) to cover the highest upper index the parent has in use; EINVAL ("already large enough") is ignored.

Related upstream items found (merged, before the pinned base): !1645 "Avoid EMFILE by reusing new_filetable_fd slot for weak fd", !1551 "Refresh filetable data before filetable creation", !1636 "Fix double close on posix_spawn". None covers this.

**Reproducer** (`x27_spawnpar_c`, pure C): 4 threads, each under a mutex creates a pipe and `posix_spawn`s `sh -c "echo x"` with its write end on stdout, then closes the read end (in some rounds outside the mutex); rounds with and without explicit close actions. Prints `spawn error N` and per-round counts.

```c
/* Concurrent posix_spawn from 4 threads, the way the Go port does it: under a
 * mutex, scan for close-on-exec descriptors, add a close action for each, dup2
 * a pipe onto the child's stdout, spawn `sh -c "echo x"`. Closes of the parent's
 * ends happen under the same mutex. Reports every spawn error (errno) and whether
 * the parent's read side saw EOF. Rounds: 1 thread, then 4 threads. */
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
static pthread_mutex_t big = PTHREAD_MUTEX_INITIALIZER;
static int errs, hangs, spawned;
static int noscan, lockclose;

static void *worker(void *arg) {
    int fds[2];
    pthread_mutex_lock(&big);
    if (pipe(fds) || fcntl(fds[0], F_SETFD, FD_CLOEXEC) || fcntl(fds[1], F_SETFD, FD_CLOEXEC)) { pthread_mutex_unlock(&big); return 0; }
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, fds[1], 1);
    if (!noscan) {
        for (int fd = 3; fd < 256; fd++) {
            int v = fcntl(fd, F_GETFD);
            if (v >= 0 && (v & FD_CLOEXEC)) posix_spawn_file_actions_addclose(&fa, fd);
        }
    }
    pid_t p = 0;
    char *av[] = {"sh", "-c", "echo x", 0};
    int e = posix_spawn(&p, "/usr/bin/sh", &fa, 0, av, environ);
    posix_spawn_file_actions_destroy(&fa);
    if (e) {
        char m[80]; snprintf(m, sizeof m, "spawn error %d (%s)\n", e, strerror(e)); write(1, m, strlen(m));
        __sync_fetch_and_add(&errs, 1);
        close(fds[0]); close(fds[1]);
        pthread_mutex_unlock(&big);
        return 0;
    }
    __sync_fetch_and_add(&spawned, 1);
    close(fds[1]);
    pthread_mutex_unlock(&big);
    char buf[16]; int n = 0, r;
    /* read until EOF, but not forever */
    fcntl(fds[0], F_SETFL, O_NONBLOCK);
    for (int i = 0; i < 200; i++) {
        r = read(fds[0], buf, sizeof buf);
        if (r == 0) break;
        if (r > 0) n += r;
        else usleep(20000);
        if (i == 199) { __sync_fetch_and_add(&hangs, 1); }
    }
    if (lockclose) pthread_mutex_lock(&big);
    close(fds[0]);
    if (lockclose) pthread_mutex_unlock(&big);
    int st; waitpid(p, &st, 0);
    return 0;
}

static void round_(int threads, int ns) {
    noscan = ns & 1; lockclose = ns >> 1; errs = hangs = spawned = 0;
    pthread_t t[8];
    for (int i = 0; i < threads; i++) pthread_create(&t[i], 0, worker, 0);
    for (int i = 0; i < threads; i++) pthread_join(t[i], 0);
    printf("threads=%d scan=%s close=%s: spawned %d, spawn errors %d, pipe never EOF %d\n", threads, (ns & 1) ? "no " : "yes", (ns >> 1) ? "locked  " : "unlocked", spawned, errs, hangs);
    fflush(stdout);
}

int main(void) {
    round_(1, 0); for (int i = 0; i < 3; i++) { round_(4, 0); round_(4, 2); round_(4, 1); }
    printf("OK x27_spawnpar_c\n");
    _exit(0);
}
```

**Verification** (relibc built in CI unpatched/patched, the repro linked against each build's libc.so as its ELF interpreter, QEMU+KVM, 2 boots per variant, 15 x27 runs of 10 rounds each; boots that hit an unrelated kernel wedge were cut short):
- unpatched: `spawn error 24 (Too many open files)` 33 and 25 times, including whole rounds where all 4 spawns failed (6 and 5 such rounds);
- patched: EMFILE 0 times in both boots (`scan=no` rounds: 0 errors in 45 + 21 rounds of 4 spawns).
- The few remaining errors are `EBADF` in the rounds where the *application* names a descriptor in a close action while another thread closes it (`scan=yes close=unlocked`): an application race, not relibc.

Runs: https://github.com/unxed/go/actions/runs/35432749858 (patched vs unpatched), https://github.com/unxed/go/actions/runs/35432404594 (earlier series without this patch: EMFILE 102 times in one boot). Workflow `redox-relibc-patches`.
