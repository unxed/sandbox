# relibc: a new thread can receive a signal its creator blocked

Against relibc master 69bb008af1 (the current head).

**Symptom.** A creator that blocks a signal and then creates a thread expects the thread to inherit the block (POSIX). With relibc a process-directed signal can be delivered to the new thread during its start-up. In practice: Go's runtime blocks all signals around `pthread_create` precisely so that a new thread cannot take a signal before its per-thread state exists; on Redox the exit of a child process (SIGCHLD) sometimes kills the program with "fatal: bad g in signal handler".

**Cause.** `new_thread_shim` calls `setup_sighandler`, which enables signal delivery and ends with `set_sigmask(Some(0))` (an EMPTY mask), and applies the mask inherited from the creator only afterwards (after `copy_masters`, the tid store and the unlock of the creator's start-up mutex). Between the two the thread has a wider mask than it inherited.

**Fix.** `setup_sighandler_with_mask(tcb, first_thread, initial_mask)`; `setup_sighandler` keeps its behaviour by passing 0. `new_thread_shim` reads the inherited mask first and passes it, so the thread never runs with a wider mask than it inherited.

Related upstream items found: closed issues #255 "pthread_sigmask is not blocking realtime signals" and #248 (pending signal delivery) concern other bugs; nothing about the start-up window.

**Reproducer** (`x33_thread_sigmask_c`, pure C, builds with `redoxer cc -pthread`):

```c
/* A new thread inherits its creator's signal mask (POSIX). The creator blocks every
 * signal, then creates many short-lived threads while a helper thread (SIGUSR1
 * unblocked) sends process-directed SIGUSR1s to the process. The handler may only ever
 * run on the helper: any other thread is a signal delivered to a thread that has it
 * blocked (in relibc: during thread start-up, before the inherited mask is applied). */
#define _GNU_SOURCE
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <unistd.h>

static pthread_t helper;
static atomic_int stop, wrong, total, ready;

static void handler(int sig) {
    atomic_fetch_add(&total, 1);
    if (!pthread_equal(pthread_self(), helper)) atomic_fetch_add(&wrong, 1);
}

static void *helper_main(void *p) {
    sigset_t s;
    sigemptyset(&s);
    sigaddset(&s, SIGUSR1);
    pthread_sigmask(SIG_UNBLOCK, &s, 0);
    while (!atomic_load(&ready)) {}
    while (!atomic_load(&stop)) { kill(getpid(), SIGUSR1); }
    return 0;
}

static void *short_lived(void *p) { return 0; }

int main(void) {
    struct sigaction sa = {0};
    sa.sa_handler = handler;
    sigaction(SIGUSR1, &sa, 0);
    sigset_t all;
    sigfillset(&all);
    pthread_sigmask(SIG_SETMASK, &all, 0);      /* creator blocks everything; children inherit */
    pthread_create(&helper, 0, helper_main, 0);
    atomic_store(&ready, 1);
    for (int i = 0; i < 1500; i++) {
        pthread_t t;
        if (pthread_create(&t, 0, short_lived, 0) == 0) pthread_join(t, 0);
    }
    atomic_store(&stop, 1);
    pthread_join(helper, 0);
    printf("handler runs: %d, on a thread that had SIGUSR1 blocked: %d\n", atomic_load(&total), atomic_load(&wrong));
    printf("%s x33_thread_sigmask_c\n", atomic_load(&wrong) == 0 ? "OK" : "FAIL");
    _exit(0);
}
```

**Verification** (relibc built in CI unpatched/patched in the redoxer environment, the repro linked against each build's libc.so as its ELF interpreter, run under QEMU+KVM):
x33_thread_sigmask_c (creator blocks all signals, 1500 short-lived threads, a helper thread with SIGUSR1 unblocked sends process-directed SIGUSR1s; the handler may only ever run on the helper): unpatched 6/6 runs FAIL with 1267, 1886 and 1614 handler runs on a thread that had the signal blocked (counted over 3 runs each in three VMs), patched 0 in 12 runs, all OK.
Runs: https://github.com/unxed/go/actions/runs/35427587571 and https://github.com/unxed/go/actions/runs/35428002403 (workflow `redox-relibc-patches`).
