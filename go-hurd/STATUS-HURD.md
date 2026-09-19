# GOOS=hurd port — status log (append-only)

Branch: `golang-1.26-hurd` (based on `golang-1.26-haiku` @ go1.26.6).
Test sandbox: `unxed/debian-hurd` (QEMU + Debian GNU/Hurd amd64 image, driven from GitHub Actions).
All builds/tests run in CI (`.github/workflows/hurd-cross-build.yml` here, `run-hurd-poc.yml` there).

## 2026-09-18 — Phase 1 done: `println("hello from hurd")` runs on real GNU Hurd

A trivial program with no stdlib imports (`func main() { println("hello from hurd") }`),
cross-compiled on Linux with `GOOS=hurd GOARCH=amd64 CGO_ENABLED=1`, runs on real
Debian GNU/Hurd (QEMU) and exits 0. Runtime initialization, `pthread_create`-based OS thread
creation (sysmon/GC workers), signal setup and `main()` all work.

### Design

Hurd has no flat raw-syscall ABI: nearly everything is a glibc function that does Mach RPC.
So the port follows the libc-calling model (`asmsysvicall6`/`asmcgocall` + `cgo_import_dynamic`),
same family as Solaris/illumos/Haiku/AIX, not Linux's freestanding syscalls.
Files: `src/runtime/{defs,os,os2,signal,netpoll,security}_hurd*.go`, `rt0_hurd_amd64.s`,
`sys_hurd_amd64.s`; `HeadType` `Hhurd` in `cmd/internal/objabi` + `cmd/link` + `cmd/internal/obj/x86`;
dynamic linker path `/lib/ld-x86-64.so.1`.

Behaves like Solaris/Haiku for the cgo `libc_xxx` symbol scheme, but like Linux/BSD/Solaris
(standard ELF, negative-offset `%fs` TLS) for TLS — NOT like Haiku's non-standard TLS slot.

### Facts measured on real Hurd (never guessed — see unxed/debian-hurd `poc/abi_probe.c`, `RESULTS.md`)

- errno values are Mach error codes (`EINTR=0x40000004`, `EAGAIN=0x40000023`, …), not small ints.
- Signal numbers above 15 differ from Linux (`SIGUSR1=30`, `SIGCHLD=20`, `SIGURG=16`, …).
- `mcontext_t`/`ucontext_t`: glibc's generic `gregs[23]` layout (REG_R8=0 … REG_CR2=22); no fs/gs slots.
- `sigset_t` is one 64-bit word; `pthread_attr_t` is 48 bytes (not pointer-sized); `sem_t` 20 bytes.
- `PROT_READ=4, PROT_WRITE=2, PROT_EXEC=1`, `MAP_PRIVATE=0`, `MAP_ANON=2`, `MAP_FIXED=0x100`.
- `pthread_create`, `pthread_kill`, `pthread_self`, `sem_*` live in **`libpthread.so.0.3`**;
  `pthread_attr_*` and everything else used are in `libc.so.0.3`.
- `issetugid()` is not exported by glibc; `secureMode` uses the AIX-style uid/gid comparison.
- Low-level primitives verified before writing the port: `gsync_wait/gsync_wake` (futex-like),
  signal delivery, `sigaltstack`+`SA_SIGINFO`+exact `si_addr` on SIGSEGV.

### Bugs found bringing it up (each root-caused with real runs, not guesses)

1. Missing `hurd` in `asm_amd64.s` `rt0_go` skip-list for the software `m0.tls` self-check
   (Solaris/illumos/Darwin/Haiku/OpenBSD skip it). Symptom: SIGTRAP/`runtime.abort` before `osinit`.
2. `libc_xxx` dynamic imports are `R_X86_64_GLOB_DAT` slots: the resolved address is *stored in*
   the slot; code must load-then-call (`MOVQ (AX), AX`), not `CALL` the slot address.
   Fixed in `asmsysvicall6`, `miniterrno`, `usleep2`, `osyield1`. Symptom: SIGSEGV with PC inside `.got`.
3. `_rt0_amd64_hurd` is the real ELF entry (no glibc `_start`), so argc/argv are on the stack
   (SysV exec ABI): must `JMP _rt0_amd64` (like Linux), not `JMP rt0_go` (Haiku). Symptom:
   SIGSEGV in `getGodebugEarly` walking a garbage argv.
4. pthread symbols split into `libpthread.so.0.3` (see above). Symptom: `undefined symbol: pthread_create`.

### Not done yet (later phases)

- `syscall`, `internal/syscall/unix`, `os`, `net` (only `runtime` is ported; programs must avoid stdlib imports).
- `stat`/`fstat` layout (deferred; not probed in detail yet).
- Native `gsync`-based `lock_futex_hurd.go` (currently POSIX semaphores via `lock_sema.go`).
- `go test` on the runtime; `crash_test.go`/`export_pipe2_test.go`/`semasleep_test.go` build tags.
- Upstreaming: not planned yet.

## 2026-09-18 — poll/sigmask constants measured (abi_probe.c, run-hurd-poc #35372599009)

`_POLLIN/_POLLOUT/_POLLERR/_POLLHUP`, `_SS_DISABLE`, `_SIG_UNBLOCK`, `_SIG_SETMASK`, `_NSIG`
had been copied from Haiku and never measured. On real Hurd:

- `POLLIN=1 POLLOUT=4 POLLERR=8 POLLHUP=16` — same as Linux, NOT Haiku. `netpoll_hurd.go` had
  `POLLOUT=2 POLLERR=4 POLLHUP=0x80` (all three wrong; would have broken the netpoller); fixed.
- `SS_DISABLE=4 SIG_UNBLOCK=2 SIG_SETMASK=3 _NSIG=33` — already correct in `os_hurd.go`.

## 2026-09-18 — Phase 2 milestone: `fmt.Println`, files, pipes, goroutines run on real Hurd

`syscall`, `internal/syscall/unix`, `internal/poll`, `os` (and everything above them: `fmt`, `time`,
`sync`, ...) are ported. Programs in `misc/hurd/tests` (`t_os`, `t_fmt`, `t_fs`, `t_rt`), cross-built in
CI, all run on Debian GNU/Hurd in QEMU with exit code 0: `fmt.Println/Printf`, `os.Stat/ReadFile/
WriteFile/ReadDir/Remove/Getwd/Hostname/Pipe`, goroutines, `time.Sleep`, tickers, GC (unxed/debian-hurd
run-hurd-poc #35380952163).

### How the layers were produced (measured, not guessed)
- `zerrors_hurd_amd64.go` and `ztypes_hurd_amd64.go` are *generated on the Hurd guest* by
  `poc/mkhurd.sh` + `poc/mkztypes_hurd.c` (unxed/debian-hurd) from the real glibc headers: constants use
  the same `#define` filter as `syscall/mkerrors.sh`; struct layouts come from `offsetof/sizeof` with
  explicit `Pad_cgo_N` and compile-time `unsafe.Sizeof` assertions. The guest has no Go, so `cgo -godefs`
  is not used. Re-run with `run-hurd-poc.yml` input `mkhurd=true`; files arrive in artifact `hurd-generated`.
- `zsyscall_hurd_amd64.go` is derived mechanically from `zsyscall_haiku_amd64.go` (every symbol is in
  `libc.so.0.3`, verified with dlsym); runtime shims `runtime/syscall{,2}_hurd.go` come from Haiku's.

### Facts measured on real Hurd (phase 2)
- POSIX errno are Mach codes `0x40000000|n`. `EKERN_*` (small) and `EMIG_*` (negative) also live in
  `<errno.h>` but are NOT errno: they must stay out of the `Errno` block and the message table (first
  generator version produced duplicate/negative table indices). `Errno.Error()` indexes the table by
  `errno & 0xffff` (special case in `syscall_unix.go`, like Haiku's).
- `struct stat` is 192 bytes (`st_fstype`, `st_fsid`(=st_dev), `st_gen`, ... become padding), `dev_t/ino_t/
  nlink_t/blksize_t/blkcnt_t` 8 bytes, `mode_t` 4. `struct dirent` = {ino u64, reclen u16, type u8,
  namlen u8, name[]}. `PATH_MAX` is undefined (we use 4096). `fd_set` is only 256 bits.
- sockaddr has BSD-style `sa_len` and an 8-bit family; `sockaddr_in`=16, `sockaddr_in6`=28,
  `sockaddr_un`=110 bytes. `Msghdr.Iovlen` is 32-bit.
- `getdirentries()` fails with `ENOSYS`; `fdopendir` + `readdir_r` work, so `syscall.ReadDirent` is
  emulated as on Haiku. ext2fs returns `d_type == DT_UNKNOWN`.
- `UTIME_OMIT=-2`, `UTIME_NOW=-1`, `AT_FDCWD=-100`, `AT_SYMLINK_NOFOLLOW=0x100`, `AT_REMOVEDIR=AT_EACCESS=0x200`,
  `O_CLOEXEC=0x400000`, `O_DIRECTORY=0x200000`, `SOCK_CLOEXEC=0x400000`, `SOCK_NONBLOCK=0x800`.
- Present in libc.so.0.3: `pipe2 accept4 dup3 openat/fstatat/... waitid posix_spawn getrandom getentropy
  stat/fstat/lstat` and all socket calls (no libsocket). Absent: `getdents`, `issetugid`, `res_init`.
- Wait status uses glibc's generic encoding (low 7 bits signal, 0x80 core, 0x7f stopped).

### Not done yet
- `net` (does not compile: needs `sock_*`, `sockopt_hurd`, `interface_*`, ...): next phase.
- `os/exec` / `fork` in a multithreaded process on glibc Hurd — untested.
- `GRND_*` are hard-coded (glibc values, not probed on Hurd).

## 2026-09-18 — net, os/exec, signals: what works and how glibc Hurd signals differ

Working on real Hurd (poc/gotests, run-hurd-poc #35398737419; each program 10/10 in `poc/loop_tests.sh`):
`net` (TCP/UDP/unix sockets on loopback, deadlines, `net/http` server+client, pure-Go resolver),
`os/exec` (fork+exec from a multithreaded process, pipes, exit status), `os/signal` (SIGUSR1),
runtime panics from hardware faults (nil deref, wild address) and the rest of phase 2.
`go build std` for hurd/amd64 has no errors.

### glibc Hurd signal delivery — two properties Go must work around (read from glibc's
`sysdeps/mach/hurd/x86/trampoline.c` and `x86_64/sigreturn.c`, confirmed with `poc/ctx_poc.c`)
1. **Register changes made by a handler are lost.** The `ucontext_t` given to an SA_SIGINFO handler is a
   copy (`fill_ucontext`); `__sigreturn(scp)` restores from the `struct sigcontext` in the same stack frame
   (mirror of `gregs[R8..RFL]` starting at `sc_r8`, 352 bytes below the ucontext). Go's sigpanic injection
   rewrites RIP/RSP, so `sigtrampgohurd` writes the changed registers back into the sigcontext (found by
   matching the original registers; `throw` if not found). This is what makes nil-deref/div panics work.
2. **The alternate stack is chosen by the `SS_ONSTACK` flag, not by SP.** A signal that arrives while a handler
   is active, or is replayed by `__sigreturn` (pending signals), runs on the interrupted user stack, i.e. on a
   goroutine stack. `sigtrampgohurd` declares that stack the signal stack for the handler's duration.
   The old Haiku-style `sigtramp` (direct `sighandler` call) could not cope; it now follows Solaris
   (`sigtramp` -> `sigtrampgo`), with `sigfwd` defined.

### Known limitation: asynchronous preemption is disabled (`preemptMSupported = GOOS != "hurd"`)
With SIGURG preemption on, even after the two fixes above one run in ~10 of the test programs still failed
intermittently (`unknown caller pc`, `fault`, hangs; with `GODEBUG=asyncpreemptoff=1` 0 failures in 70+ runs).
Cause not found: the injected `asyncPreempt` call itself works (rip/rsp rewrites verified, tight-loop test passed
in most runs). Consequence: a goroutine in a loop without function calls cannot be preempted, so a GC
stop-the-world can wait for it forever. Cooperative preemption still works. Revisit later.

### Tooling notes
- `run_poc.py` runs every `poc/gotests/*.bin` under a guest-side `timeout -s KILL 60` (never Ctrl-C: it kills QEMU).
- `run-hurd-poc.yml` inputs: `mkhurd` (regenerate zerrors/ztypes), `loops` (10x flakiness statistics).

## 2026-09-19 — f4 (unxed/f4) runs on real Hurd: console + panels + built-in terminal

`hurd-f4-build.yml` (push to `.github/f4-ref` triggers it) cross-compiles `unxed/f4` with this toolchain
(`CGO_ENABLED=0`); `run-hurd-poc.yml` runs it in QEMU (KVM when the runner has it). Result (run #35409126369):
two-panel UI on `/` (22 entries), a command typed on the command line runs through the built-in terminal
(PTY + fork/exec + bash: `echo f4-$((20+22))-ok` prints `f4-42-ok`), F10 -> "Leave f4?" -> exit code 0.
No goffi/GPU for this milestone: console (and X11 without FFI, untested) only.

### How f4 is built for Hurd (CI only; nothing of this is in unxed/f4 yet)
- `go mod vendor`, then `.github/scripts/hurd_retag.py` treats `hurd` like `solaris` in `//go:build`
  lines of vendored deps and f4 itself (libc OS without FFI: picks the no-FFI stubs, unix code paths).
  `x/sys` and `x/net` are skipped. f4's own retagged files: `misc/hurd/f4-own-changes.patch`.
- `golang.org/x/sys/unix` has no gc/hurd port: `misc/hurd/xsys-unix/` is a stand-in copied over
  `vendor/golang.org/x/sys/unix` (API used by f4 and its deps only; constants generated from
  `syscall/zerrors_hurd_amd64.go`). libc calls outside `syscall` do not link (R_PCREL/R_ADDR against
  SDYNIMPORT), so the shim reaches them through one pushed linkname, `syscall.extCall`
  (`src/syscall/ext_hurd.go`: tcgetattr/tcsetattr/ioctl/poll/mprotect/fchmodat/flock/getpgid/posix_openpt/...;
  dispatch is a `switch` because data tables of dynamic-import addresses are not linkable either).
- `misc/hurd/f4-overlay/internal/terminal/pty_hurd.go`: PTY backend. Measured (poc/pty_poc.c): BSD ptys
  (master `/dev/ptyXN`, slave `/dev/ttyXN`, no /dev/ptmx or /dev/pts); posix_openpt/grantpt/unlockpt/
  ptsname work; master is non-blocking and pollable; TIOCSCTTY after setsid works; TIOCGPGRP on the
  master fails (IsBusy asks the slave). afero: BADFD is EBADF on Hurd (no EBADFD).
- What still needs upstream work: f4/vtui/vtinput constraints for hurd, `pty_hurd.go`, an x/sys/unix Hurd
  port (or a hurd shim module), afero `const_bsds.go`.

### Runtime bugs found by running f4 (fixed)
- **Threads**: glibc Hurd's default pthread stack is 8 MB of *committed* memory; with 2 GB of RAM
  `pthread_create` returns EAGAIN after ~236 threads (C probe poc/thr_poc.c: 400 threads fine with 256K/64K
  stacks; anonymous mmap tops out at ~1.85 GB even untouched). Every goroutine blocked in a libc call holds an
  OS thread (`entersyscallblock`), so f4's daemon died with `failed to create new OS thread` at 11-24
  threads. `newosproc` now asks for 1 MB (+64K) stacks, what `tstart_sysvicall` assumes anyway.
  `t_threads` (100 blocked readers) passes.
- f4 quirks under emulation: `daemonStartTimeout` (10 s) in f4's session code is too short for TCG;
  KVM removes the problem.

### Known limitations
- Asynchronous preemption disabled (see above). No `os/user` cgo. X11 backend not tried.
