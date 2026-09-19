# kernel: a futex sleeper is never woken after fork() when the page holding the futex word moves (copy-on-write)

Against kernel master 2d2eef740a (the current head).

**Symptom.** A multi-threaded program forks (or `posix_spawn`s through `fork`); the child stays alive for a while. Afterwards a thread that was already sleeping in `FUTEX_WAIT` (e.g. `sem_wait`) before the fork is never woken by a `sem_post`/`FUTEX_WAKE` from another thread of the same process: it sleeps forever. Go's runtime (worker threads parked on semaphores) stalls after the first `os/exec` that uses fork.

**Cause.** Futexes are keyed by physical address. At fork the parent's pages become shared copy-on-write. The first write by the parent to the page holding the futex word (`sem_post` itself does it) is a page fault that gives the writer a NEW frame. The sleeper was queued under the OLD frame's address, the wake-up is translated through the new mapping and looks under the new address: no match.

MR !650 ("Fix futex on shared memory by correcting CoW pages before translation", merged, in the base) fixes the case of a thread that starts waiting after the fork (the waiter un-shares its page first). It does not help a thread that was already asleep when the fork happened. MR !301 ("Fix futex wakeup when CoW has occurred") is the older attempt; the base no longer has its virtual-address bookkeeping. No open issue about this found (searched futex, fork, copy-on-write).

**Fix.** When the page fault handler gives a writer a new frame (`correct_inner`, the `cow()` call with `old_frame == Some(..)`), call the new `futex::wake_frame(old_frame)`: it removes and wakes every waiter queued inside the old frame. FUTEX_WAIT may return spuriously, so the woken thread re-reads the futex word through its updated mapping and waits again under the new address if the condition still does not hold. Pages that are not moved (exclusive) are unchanged; the cost is one lock and an emptiness check per moved page when no futex is registered. Lock order is the one `futex()` already uses (address space, then FUTEXES).

**Reproducer** (`x23_futex_fork_c`, pure C): a helper thread sleeps in `sem_wait`; the main thread forks (child alive for 400 ms), then `sem_post`s; the helper must wake. Compared with `posix_spawn` (no CoW) and no fork as controls.

```c
/* Hypothesis test (pure C): a fork() in a multithreaded process makes the parent's
 * pages copy-on-write. The kernel keys futexes by *physical* address, so when the
 * parent writes to the semaphore word (sem_post) its page is copied to a new
 * physical page, and FUTEX_WAKE no longer finds the thread that went to sleep on
 * the old page => the sleeper is never woken.
 *
 * For each round: a helper thread sleeps in sem_wait(); the main thread (a)
 * optionally fork()s and reaps a child, (b) sem_post()s. The helper must wake.
 * Also tried: the helper is created *before* fork, and the semaphore lives on the
 * heap vs. in .bss. */
#include <pthread.h>
#include <spawn.h>
#include <semaphore.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static sem_t bss_sem;
static sem_t *heap_sem;
static _Atomic int woken;

static void *sleeper(void *p) {
    sem_t *s = p;
    while (sem_wait(s) != 0) {}
    atomic_store(&woken, 1);
    return 0;
}

static char *self;
extern char **environ;

/* mode 0: no fork; 1: fork, child exits at once and is reaped (page is exclusive again);
 * 2: fork, child stays alive for 400 ms across the sem_post (page stays shared => CoW copy);
 * 3: posix_spawn(self "child"), child stays alive for 400 ms across the sem_post */
static int round_(int mode, int use_heap) {
    sem_t *s = use_heap ? heap_sem : &bss_sem;
    sem_init(s, 0, 0);
    atomic_store(&woken, 0);
    pthread_t t;
    pthread_create(&t, 0, sleeper, s);
    struct timespec d = {0, 150 * 1000 * 1000};
    nanosleep(&d, 0);                      /* let the helper block in the futex */
    pid_t c = 0;
    if (mode == 1 || mode == 2) {
        c = fork();
        if (c == 0) {
            if (mode == 2) { struct timespec k = {0, 400 * 1000 * 1000}; nanosleep(&k, 0); }
            _exit(0);
        }
        if (mode == 1) { int st; waitpid(c, &st, 0); c = 0; }
    } else if (mode == 3) {
        char *av[] = {self, "child", 0};
        if (posix_spawn(&c, self, 0, 0, av, environ) != 0) { printf("posix_spawn failed\n"); c = 0; }
    }
    sem_post(s);                           /* writes the page that fork() made CoW */
    for (int i = 0; i < 100; i++) {        /* up to 2 s */
        if (atomic_load(&woken)) break;
        struct timespec w = {0, 20 * 1000 * 1000};
        nanosleep(&w, 0);
    }
    int ok = atomic_load(&woken);
    if (ok) pthread_join(t, 0);            /* on a lost wake-up the helper stays asleep: leak it */
    if (c > 0) { int st; waitpid(c, &st, 0); }
    return ok;
}

int main(int argc, char **argv) {
    self = argv[0];
    if (argc > 1 && strcmp(argv[1], "child") == 0) {
        struct timespec k = {0, 400 * 1000 * 1000};
        nanosleep(&k, 0);
        _exit(0);
    }
    heap_sem = malloc(sizeof *heap_sem);
    int fails = 0;
    static const char *names[] = {"no fork", "fork, child gone", "fork, child alive", "posix_spawn, child alive"};
    for (int use_heap = 0; use_heap < 2; use_heap++)
        for (int mode = 0; mode < 4; mode++) {
            int okc = 0, n = 4;
            for (int i = 0; i < n; i++) okc += round_(mode, use_heap);
            printf("%s sem, %-24s: %d/%d woke\n", use_heap ? "heap" : "bss ", names[mode], okc, n);
            fflush(stdout);
            if ((mode == 0 || mode == 3) && okc != n) fails++;
        }
    printf("%s x23_futex_fork_c\n", fails ? "FAIL" : "OK");
    _exit(0);
}
```

**Verification** (kernel built in CI, master vs patched, QEMU+KVM, 4 CPUs, x23 twice per boot, two boots per variant): "fork, child alive" - master 0/4 woke in all 8 runs (bss and heap semaphore, 2 boots); patched 4/4 in all 8. Controls (`posix_spawn`, no fork) 4/4 everywhere. Exit-hang repro (x17, with the ForceKill patch also applied) and a concurrent-`posix_spawn` stress (x27) show no new failures: exit hangs with both patches 0/60 (`exit()`) and 0/30 (`_exit`) in both boots; the spawn stress wedges some boots on every variant including unpatched master (a separate, pre-existing exit_this_context problem).

Run: https://github.com/unxed/go/actions/runs/35428992551 (workflow `redox-kernel-verify`, variants baseline / cow / both).
