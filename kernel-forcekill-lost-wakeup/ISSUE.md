Title: Thread stays blocked forever after procmgr ForceKill at process exit (lost wakeup in Context::block)

## Symptom

A multi-threaded process that calls `exit()` or `_exit()` sometimes never finishes exiting. Afterwards
exactly one thread of the process is left in state `UB` (blocked, no wakeup pending) in
`/scheme/sys/context`, every other thread is dead, and procmgr is idle. Observed with Go programs
and reproduced with plain C (3 pthread pairs doing sem ping-pong; main calls `exit(0)` after a random
0-15 ms). Hang rates under redoxer/QEMU on kernel 2d2eef7: about 27% (16 of 60) unpatched.

## Cause

procmgr's `on_exit_start` writes ForceKill to every thread (`ContextVerb::ForceKill`: status =
Runnable, `being_sigkilled = true`, wakeup). If that lands just before the target thread blocks (futex
wait, `sem_wait`), `Context::block()` overwrites the status with `Blocked` unconditionally, so the
wakeup is lost. The thread returns unkilled from its syscall, blocks again with no timeout, and nobody
wakes it. In addition, the syscall-exit check reads a per-CPU copy of `being_sigkilled` that is refreshed
only in `switch_to`, so `switch_inner`'s "already current" early return leaves it stale.

## Fix

See the attached patch: `block()` refuses to block a sigkilled context, and the early return in
`switch_inner` refreshes the per-CPU copy.

Kernel rebuilt in CI with and without the patch, hang counts:

    exit(0) variant, 60 runs: stock image kernel 19, master 16, patched 0
    default variant, 30 runs: stock image kernel 1, master 0, patched 0
