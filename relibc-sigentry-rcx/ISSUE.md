Title: x86_64: __relibc_internal_sigentry clobbers the interrupted thread's RCX with the signal number

## Summary

On x86_64, every asynchronously delivered signal silently corrupts `rcx` of the interrupted code. After the handler returns, `rcx` holds the 0-based signal number (e.g. `0x16` for SIGURG) instead of its previous value.

## Cause

`redox-rt/src/arch/x86_64.rs`, `__relibc_internal_sigentry`. At entry the function stashes `rsp, rax, rdx, rdi, rsi, r8, r10, r12` in the TCB signal area, but not `rcx`. Further down, it uses `rcx` as scratch:

```asm
    mov ecx, eax
    and ecx, 63

    // LEA doesn't support 16x, so just do two x8s.
    lea rdx, [rdx + 8 * rcx]
    lea rdx, [rdx + 8 * rcx]
```

and only afterwards builds the signal frame with `push rcx`, which now pushes the signal number. `pop rcx` at the end restores that value into the interrupted thread. (The kernel-initiated signal path saves only IP and RFLAGS, so `rcx` is live application state here.)

## Fix

Use a register that was already saved to the TCB and is pushed from there (`r10`) as scratch. See the attached patch (1 hunk, 3 lines).

## How it was found

Go's runtime port to Redox (GOOS=redox, `libc.so.6`) uses SIGURG for asynchronous preemption. Under QEMU (slow TCG), sysmon preempts even tiny programs. Symptoms: random crashes, e.g. a register dump with `RCX=0x16`, and a key-string pointer equal to `0x16` (moved out of a clobbered `rcx`) faulting in a hash function. A control test that sends a SIGURG barrage passes with async preemption disabled (`GODEBUG=asyncpreemptoff=1`) and crashes with it enabled.

The same code is on `master` (checked 2026-09-18, commit 69bb008af1).
