# relibc: poll() fails the whole call when one descriptor is a regular file

Against relibc master 69bb008af1 (the current head).

**Symptom.** `poll()` returns -1 with `errno == EPERM` as soon as one of the descriptors is a regular file (or a directory), so a program that polls a pipe and also has a regular file in the set cannot use `poll` at all. POSIX: "Regular files shall always poll TRUE for reading and writing."

**Cause.** `poll_epoll` registers each descriptor with `epoll_ctl(EPOLL_CTL_ADD)`. That fails with EPERM for descriptors epoll cannot watch (regular files, directories), and every error other than EBADF makes the whole call return -1.

**Fix.** On EPERM report the requested `POLLIN`/`POLLOUT`/`POLLRDNORM`/`POLLWRNORM` bits as `revents` for that descriptor, count it as ready and call `epoll_pwait` with a zero timeout (so the other descriptors are still collected, but the call does not sleep with something ready).

Related upstream items found: none about this (issue #156 "Hang in Rust's test" mentions epoll_ctl but is a different problem; MR !1557 "Fix crash at poll() when timed out" merged earlier, unrelated).

**Reproducer** (`x32_poll_regular_c`, pure C, builds with `redoxer cc -pthread`):

```c
/* poll() with a regular file among the descriptors. POSIX: regular files are always
 * ready. relibc's poll (epoll based) failed the whole call with EPERM. */
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    int ok = 1;
    int fd = open("/tmp/x32.txt", O_RDWR | O_CREAT | O_TRUNC, 0644);
    write(fd, "hello\n", 6);
    lseek(fd, 0, SEEK_SET);
    int p[2];
    pipe(p);

    struct pollfd a = {fd, POLLIN | POLLOUT, 0};
    int n = poll(&a, 1, 500);
    printf("regular file alone:          n=%d revents=%#x errno=%d (%s)\n", n, a.revents, n < 0 ? errno : 0, n < 0 ? strerror(errno) : "-");
    if (n != 1 || (a.revents & (POLLIN | POLLOUT)) != (POLLIN | POLLOUT)) ok = 0;

    struct pollfd b[2] = {{p[0], POLLIN, 0}, {fd, POLLIN, 0}};
    n = poll(b, 2, 500);
    printf("idle pipe + regular file:    n=%d pipe=%#x file=%#x errno=%d\n", n, b[0].revents, b[1].revents, n < 0 ? errno : 0);
    if (n != 1 || b[0].revents != 0 || !(b[1].revents & POLLIN)) ok = 0;

    write(p[1], "x", 1);
    struct pollfd c[2] = {{p[0], POLLIN, 0}, {fd, POLLIN, 0}};
    n = poll(c, 2, 500);
    printf("ready pipe + regular file:   n=%d pipe=%#x file=%#x\n", n, c[0].revents, c[1].revents);
    if (n != 2 || !(c[0].revents & POLLIN) || !(c[1].revents & POLLIN)) ok = 0;

    struct pollfd d = {p[1], POLLOUT, 0};
    n = poll(&d, 1, 500);
    printf("pipe write end only (control): n=%d revents=%#x\n", n, d.revents);
    if (n != 1 || !(d.revents & POLLOUT)) ok = 0;

    unlink("/tmp/x32.txt");
    printf("%s x32_poll_regular_c\n", ok ? "OK" : "FAIL");
    _exit(0);
}
```

**Verification** (relibc built in CI unpatched/patched in the redoxer environment, the repro linked against each build's libc.so as its ELF interpreter, run under QEMU+KVM):
x32_poll_regular_c: unpatched 4/4 runs FAIL (n=-1, EPERM), patched 4/4 runs OK (regular file alone, regular file + idle pipe, regular file + ready pipe, and a pipe-only control).
Runs: https://github.com/unxed/go/actions/runs/35427587571 and https://github.com/unxed/go/actions/runs/35428002403 (workflow `redox-relibc-patches`).
