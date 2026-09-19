# Redox issues found while porting Go

Each one was reduced to a small program in `.github/redox/ladder/` (C wherever possible).
CI = GitHub Actions on unxed/go, branch `golang-1.26-redox`, QEMU with KVM, 4 CPUs, redoxer's image.
Runs: `https://github.com/unxed/go/actions/runs/<id>`.

| # | where | issue | repro | CI run | status |
|---|---|---|---|---|---|
| 1 | kernel | A ForceKill that lands while the target thread is about to block is lost (`Context::block()` overwrites Runnable with Blocked); the process never finishes exiting | `x17_exit_c` | 35410254114 (v3: patched 0/60 `exit()` and 0/30 `_exit`; stock 3/60; master 22/60 and 6/60); v2 in 35403271670 | **patch v3 verified**: `../kernel/0001-futex-don-t-sleep-on-an-untimed-wait-when-the-contex.patch`, `../kernel/ISSUE.md` |
| 2 | kernel | Futexes are keyed by physical address; `fork()` makes the parent's pages copy-on-write, the parent's next write moves the page, and threads already asleep on the old frame are never woken (`sem_post` finds nobody). MR !650 (in the base) only covers waiters that start waiting after the fork | `x23_futex_fork_c` | 35428992551 (master: "fork, child alive" 0/4 woke in 8 of 8 runs; patched 4/4 in 8 of 8; exit repro with the ForceKill patch 0/60 and 0/30) | **patch verified**: `../kernel/0002-*.patch`, unxed/sandbox `kernel-futex-cow-wake/` (wake the old frame's waiters when a CoW fault moves a page) |
| 3 | kernel + procmgr | CPU exceptions are never delivered to a user signal handler (`excp_handler` in `context/signal.rs` is a TODO): the faulting thread is killed with "UNHANDLED EXCEPTION" and, because procmgr starts the exit only once *all* threads are dead, a multi-threaded process just lingers | `x24_nilpanic` at 35400663199 (before the compiler emitted explicit nil checks) | 35400663199 | worked around in the Go compiler (explicit nil checks); not fixed |
| 4 | relibc | `posix_spawn` does not close the parent's close-on-exec descriptors in the child (a `cat` child keeps the write end of its own stdin pipe open and never sees EOF). Cause: the close list is sent to the filetable `Close` verb in one call, the kernel's `bulk_remove_files` is all-or-nothing, and the list names fds the child's table lacks, so it fails with EBADF, ignored | `x26_spawn_cloexec_c` | 35428002403 (unpatched 4/4 FAIL, patched 4/4 OK) | **patch verified**: unxed/sandbox `relibc-spawn-cloexec/` |
| 5 | relibc | `posix_spawn` fails with EBADF when other threads close/open descriptors at the same time, and a failed spawn leaves a half-built child process (holding copies of every fd, so pipes never reach EOF; a never-started child that is later killed runs with all registers zero and can wedge the kernel, #9). Narrowed down with a debug build (run 35428330310): 122 of 124 failures are the call in `Sys::spawn` that hands the child's filetable over (`new_file_table.call_wo(<its own fd>, FD \| FD_CLONE)`, base line 1330), the rest a `Close` action; it happens only while other threads close descriptors (`x27_spawnpar_c` rounds "scan=no close=unlocked"). Suspect: the fd number is no longer valid in the caller's table at that moment, i.e. a race between `close()` (kernel close first, userspace `FILETABLE` bookkeeping after) and descriptor allocation | `x27_spawnpar_c` (pure C); not changed by patch #4 | 35428330310 | open: cause narrowed, no fix yet |
| 6 | relibc | a new thread starts with an empty signal mask and applies the creator's mask a little later (`pthread/mod.rs`); a process-directed signal can hit it before its state exists | `x33_thread_sigmask_c` (unpatched: 1267/1886/1614 handler runs on a thread with the signal blocked; patched 0); Go: "fatal: bad g in signal handler" in `x20_execpar` | 35428002403 | **patch verified**: unxed/sandbox `relibc-pthread-sigmask/` |
| 7 | relibc | `sigentry` clobbers RCX of the interrupted code | `x10_sigstorm` | (earlier) | fixed upstream: unxed/relibc `fix-sigentry-rcx-clobber` (8022058e); Go still keeps async preemption off by default until the image has the fix |
| 8 | relibc | `poll()` fails the *whole call* (EPERM) when one descriptor is a regular file (epoll_ctl refuses it) | `x32_poll_regular_c` | 35428002403 (unpatched 4/4 FAIL, patched 4/4 OK) | **patch verified**: unxed/sandbox `relibc-poll-regular-files/` |
| 9 | kernel | a context that takes an exception (here: a just-spawned child that ran with garbage state, page fault at RIP 0 or #UD) and calls `exit_this_context` can wedge the kernel: `context::switch` returns to the dead context and `unreachable!()` panics at `syscall/process.rs:83`, or the VM silently freezes after "UNHANDLED EXCEPTION". Seen on the stock kernel (freeze, 1/2 runs), master (faults survived) and both patch versions (panic v2 2/2, v3 1/2) - not caused by the ForceKill patch | `x27_spawnpar_c` (40 rounds of 4 concurrent spawns) | 35409694501, 35410254114 | open; needs a look at `select_next_context`/`AllContextsIdle` for a dead current context whose sched context differs (direct switch) |
| 10 | QEMU TCG only | CLOCK_MONOTONIC / CLOCK_REALTIME read on different vCPUs go backwards by up to ~4 ms | `x21_clock_c` | 35392788829 | gone with KVM |

Checked and *not* a bug: `poll()` on a pty slave (C `x29_pty_c` and f4-redox's pollprobe both get POLLIN correctly, canonical and raw). The Go port still ticks terminals every 10 ms as a precaution (`netpoll_redox.go`).

Not a bug, but easy to trip over: a process created by `posix_spawn` starts with all-zero FPU
control state. relibc's `crt0` sets MXCSR/x87 CW (`src/crt0`), so C programs are fine; an ELF entry
point that bypasses crt0 (Go's, internal linking) must do it itself (done in `_rt0_amd64_redox`).

## Reproducing with redoxer's images

`.github/redox/vm_run.sh <script> <log> [kernel]` boots one VM; with a kernel file it first lets
redoxer build its base image (a tar under `~/.redoxer/x86_64-unknown-redox/`) and swaps
`usr/lib/boot/kernel` inside it. Kernel: `make ARCH=x86_64 OBJCOPY=objcopy` from the pinned source
(nightly-2026-05-24, `nasm`). Workflow: `.github/workflows/redox-kernel-verify.yml`.
