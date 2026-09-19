# kernel: an exiting process can hang forever – a ForceKill that lands while a thread is going to sleep is lost

**Symptom.** A multi-threaded program calls `exit(0)` (or `_exit(0)`), prints everything it
wanted to print, and never terminates. `/scheme/sys/context` shows the process with exactly one
thread left, in state `UB` (blocked, no wakeup pending), every other thread already dead, and
procmgr idle. `waitpid` in the parent never returns. About 30 % of runs of the reproducer below
under QEMU/TCG with 2 CPUs; the same signature shows up in Go programs (≈10 % of runs, `_exit`
from the Go runtime) and in `sh` children of `os/exec`.

**Reproducer** (`.github/redox/ladder/x17_exit_c/main.c`, pure C, no Go): three pairs of
threads ping-pong on POSIX semaphores (so threads constantly enter and leave *untimed* futex
waits); `main` sleeps a pseudo-random 0–15 ms, prints `OK`, and calls `exit(0)`.
Hang counts of `exit(0)` over 60 runs, redoxer image kernel: **19/60**; kernel master built from
source: **16/60**; master + the patch below: **0/60** (`_exit`: 1/30, 0/30, 0/30).

**Cause.** procmgr (`on_exit_start`) terminates a process by writing `usize::MAX`
(`ContextVerb::ForceKill`) to the status handle of every thread. For a thread other than the
caller the kernel does (scheme/proc.rs)

    ctxt.status = Runnable; ctxt.being_sigkilled = true; wakeup_context(..)

which is enough only if the target is asleep. If the target is on another CPU, past its own
pending-signal check (`futex()` checks `currently_pending_unblocked`, `UserInner::call` blocks
first) but before `Context::block()`, then `block()` overwrites `Runnable` with `Blocked`
(`if self.status.is_runnable() { self.status = Status::Blocked; .. }`). The wakeup has already
been consumed and `being_sigkilled` is only consulted when the context next runs (on
`switch_to` / at syscall exit), which now never happens. The thread stays `Blocked` for good,
procmgr keeps waiting in `AwaitingThreadsTermination`, the process never becomes a zombie.

A second, related hole: the syscall exit path tests the *per-CPU copy*
`switch_internals.being_sigkilled`, which is refreshed only in `switch_to()`.
`switch_inner()` returns early when the scheduler picks the context that is already current
("no switch needs to be done"), so a context that was killed while on its way to sleep can
return to userspace with a stale `false`.

**Fix.** (`0001-futex-don-t-sleep-on-an-untimed-wait-when-the-contex.patch`, v3)

1. `futex(FUTEX_WAIT)` returns EINTR without blocking when `being_sigkilled` is set. The check sits
   in the same critical section (the context write lock that ForceKill also takes) as the
   pending-signal check and `Context::block()`, so exactly one of them happens first. It also
   stores `true` in the per-CPU copy of the flag, because we are the running context and will not switch.
2. `switch_inner()` refreshes the per-CPU `being_sigkilled` copy on the "already current" early return.

(v2 made `Context::block()` itself refuse to block a sigkilled context. That fixed the hang too, but
broke the invariant of `UserInner::call_inner`, which blocks and then direct-switches to the scheme
handler: a dying context whose close calls no longer blocked made `exit_this_context`'s final
`context::switch` return and hit `unreachable!()` (process.rs:83) in 2 of 2 runs of a concurrent
`posix_spawn` stress, 0 of 4 on unpatched kernels. v3 changes only the futex path.)

**Not covered / caveats.** Verified only on x86_64 under QEMU with `-smp 2` (TCG, which makes
the window wide). The futex wait leaves its `FutexEntry` behind when `block()` declines; the
context is dying, so it is harmless, but a `FUTEX_WAKE` may count it as woken.
