# MR title: redox-rt/x86_64: don't clobber rcx in __relibc_internal_sigentry

Fixes: asynchronous signals corrupt RCX of the interrupted thread (see ISSUE.md). Commit: `git am` the .patch next to this file.

# Verification of sigentry-rcx.patch (for the upstream MR description)

Workflow: `.github/workflows/redox-relibc-verify.yml` (run
https://github.com/unxed/go/actions/runs/35387410427, commit 2167a589 on branch
golang-1.26-redox of unxed/go).

Setup
* relibc = upstream master `69bb008af1f6d93758631cf0df250500d53a065b` (fetched from
  gitlab.redox-os.org), built with `make PROFILE=release libs` in the
  `redoxos/redoxer` image (redoxer toolchain, rustc 1.98.0-dev), once unmodified
  and once with `sigentry-rcx.patch`; the two `libc.so` differ
  (sha256 43ecad82... vs 9a1a1238...).
* The same Go programs are linked twice with `-I <that build's ld64.so.1>`
  (relibc's `libc.so` is also the dynamic linker), so each process runs on exactly
  one of the two libcs. Run in a Redox VM (redoxer/QEMU, `-smp 2`) with
  `GODEBUG=asyncpreemptoff=0`, i.e. Go's runtime sends SIGURG to threads
  running goroutines (asynchronous signals, thread-directed via pthread_kill).

Results
| program | unpatched relibc | patched relibc |
|---|---|---|
| x10_sigstorm (SIGURG barrage while 4 workers verify a deterministic computation) | 0/2 pass (both crash) | 2/2 pass |
| p02_fmt (`fmt.Println`, 15 runs each) | 1 crash, 14 clean | 0 crashes, 13 clean + 2 "printed OK, then hung at exit" |

Every unpatched crash has the same signature: `RCX = 0x16` (the 0-based number of
SIGURG, 23-1) in the fault dump, e.g. x10: `Page fault: 0x16`, RIP inside
`main.work`, RCX=0x16; p02: `RCX=0x16`, fault address `0x1E`. Patched runs show
no register corruption at all.

The "printed OK, then hung at exit" outcome occurs with and without the patch (and
also with async preemption off), so it is a different problem: relibc's `exit()`
calls `pthread::terminate_from_main_thread`, which cancels all other threads with
`SIGRT_RLCT_CANCEL`; Go now calls `_exit` instead, and a smaller rate of exit hangs
remains (~10% of runs in a multi-threaded process); not investigated further.
