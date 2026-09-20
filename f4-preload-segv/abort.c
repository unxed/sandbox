/* Stands in for ESET's libesets_pac.so (f4 #1213): aborts in its constructor,
   but only in the process the universal build re-executes through the host
   loader (a loader started with --preload and an image named /proc/self/fd/N),
   and leaves every other process alone. */
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
__attribute__((constructor)) static void init(void) {
    char buf[4096];
    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0) return;
    ssize_t n = read(fd, buf, sizeof buf - 1);
    close(fd);
    if (n <= 0) return;
    for (ssize_t i = 0; i < n; i++) if (buf[i] == 0) buf[i] = ' ';
    buf[n] = 0;
    if (strstr(buf, "--preload") && strstr(buf, " /proc/self/fd/")) abort();
}
