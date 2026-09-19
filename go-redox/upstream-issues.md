# Redox issues found while porting Go

Each one was reduced to a small program in `.github/redox/ladder/` (C wherever possible).
CI = GitHub Actions on unxed/go, branch `golang-1.26-redox`, QEMU with KVM, 4 CPUs, redoxer's image.
Runs: `https://github.com/unxed/go/actions/runs/<id>`.

| # | where | issue | repro | CI run | status |
|---|---|---|---|---|---|
| 1 | kernel | A ForceKill that lands while the target thread is about to block is lost (`Context::block()` overwrites Runnable with Blocked); the process never finishes exiting | `x17_exit_c` | 35403271670 (stock 14/60 `exit()` hangs, master 8/60, patched 0/60; `_exit` 2/30, 0/30, 0/30) | **patch verified**: `../kernel/0001-futex-don-t-sleep-on-an-untimed-wait-when-the-contex.patch`, `../kernel/ISSUE.md` |
| 2 | kernel | Futexes are keyed by physical address; `fork()` makes the parent's pages copy-on-write, the parent's next write moves the page, and sleepers on the old frame are never woken (`sem_post` finds nobody) | `x23_futex_fork_c` | 35399661211 (child alive across `sem_post`: 0/4 woke; `posix_spawn`: 4/4; no fork: 4/4) | worked around in Go (`posix_spawn`, timed `semasleep`); kernel fix not written (idea: wake waiters of the old frame on the CoW copy, or key private futexes by address space + vaddr) |
| 3 | kernel + procmgr | CPU exceptions are never delivered to a user signal handler (`excp_handler` in `context/signal.rs` is a TODO): the faulting thread is killed with "UNHANDLED EXCEPTION" and, because procmgr starts the exit only once *all* threads are dead, a multi-threaded process just lingers | `x24_nilpanic` at 35400663199 (before the compiler emitted explicit nil checks) | 35400663199 | worked around in the Go compiler (explicit nil checks); not fixed |
| 4 | relibc | `posix_spawn` does not close the parent's close-on-exec descriptors in the child (a `cat` child keeps the write end of its own stdin pipe open and never sees EOF) | `x26_spawn_cloexec_c` | 35406285068 (fork+exec: cat exited; posix_spawn: cat HUNG) | worked around in Go (explicit `addclose`) |
| 5 | relibc | `posix_spawn` fails with EBADF for some descriptor layouts when several children are started concurrently and leaves a half-built child process (holding copies of every fd) behind | Go: `x20_execpar`, `p14_exec` (C `x27_spawnpar_c` and, single-threaded, every action layout of `x31_spawn_actions_c` succeed, so it is concurrency-related) | 35406285068 | worked around in Go (fall back to fork on EBADF); cause unknown |
| 6 | relibc | a new thread starts with an empty signal mask and applies the creator's mask a little later (`pthread/mod.rs`); a process-directed signal (SIGCHLD of an exited child) can hit it before its TLS/`g` exists | Go: "fatal: bad g in signal handler" in `x20_execpar` | 35400663199 | worked around in Go (drop benign async signals on a g-less thread) |
| 7 | relibc | `sigentry` clobbers RCX of the interrupted code | `x10_sigstorm` | (earlier) | fixed upstream: unxed/relibc `fix-sigentry-rcx-clobber` (8022058e); Go still keeps async preemption off by default until the image has the fix |
| 8 | relibc | `poll()` fails the *whole call* (EPERM) when one descriptor cannot be watched, e.g. a regular file | found by f4-redox, unxed/sandbox run 35399359761; no C repro yet | | worked around in Go (`netpollopen` probes each fd) |
| 9 | kernel (or relibc spawn) | under 4-way concurrent `posix_spawn`, a just-spawned child ran with all registers zero (page fault at RIP 0) and the kernel then panicked in `exit_this_context` (`syscall/process.rs:83`, `context::switch` returned to a dead context) - seen once, on the patched kernel (35407656018); not reproduced in 8 repeats on either kernel (run 35408639606) | `x27_spawnpar_c` | 35407656018 | open |
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
