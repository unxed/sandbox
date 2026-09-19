# relibc: a posix_spawn'ed child can die with "Invalid opcode fault" in the dynamic loader (all-zero FPU control state)

Against relibc master 69bb008af1 (the current head).

**Symptom.** Now and then a child started with `posix_spawn` is killed before `main`:

```
Invalid opcode fault
RFLAG: ...  CS: 000000000000002b  RIP: 000000000004ca72 ... 
kernel::context::signal:INFO -- UNHANDLED EXCEPTION, ... NAME /root/mnt/x27_spawnpar_c.bin
```

The child is a dynamically linked program (`sh`), its name is still the parent's (it never got as far as exec), and the faulting code is the loader's.

**Cause.** A context created by `posix_spawn` starts with all-zero FPU control state; a forked or exec'ed process inherits sane values. MXCSR = 0 leaves every SSE exception unmasked, and because the kernel does not set CR4.OSXMMEXCPT the first inexact SSE result raises #UD instead of #XM. `crt0` initialises MXCSR and the x87 control word (`src/crt0/src/lib.rs`), but the interpreter, relibc's own `ld_so` `_start`, runs first and executes Rust code (with floating point in it) under the zeroed state. The same thing kills a Go program spawned this way in its runtime start-up ("Invalid opcode fault" in `runtime.fastexprand`), which is how it was found.

**Fix.** At the top of the x86_64 `_start` in `ld_so/src/lib.rs`: `fninit` and `ldmxcsr` of 0x1f80, before any Rust code runs.

Related upstream items found: none (searched mxcsr, invalid opcode, fninit, ld.so).

**Reproducer.** There is no small deterministic one (the loader's floating point rarely produces an inexact result); the failure rate is a few percent of spawned children. Statistical A/B: `x27_spawnpar_c` (4 threads spawning `sh`, 25 runs per boot, 6 boots per variant, KVM), relibc series unpatched vs patched: **4 "Invalid opcode fault" children in 137 runs unpatched (one boot then wedged the kernel, see the kernel issue about exit_this_context), 0 in 150 runs patched**. (The series also contains the EMFILE fix, which makes more spawns succeed, so it cannot be what removes the faults.) Run: https://github.com/unxed/go/actions/runs/35434508726 (workflow `redox-relibc-patches`).
