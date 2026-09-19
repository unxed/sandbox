# relibc: posix_spawn racing with pthread_create starts the new thread with all registers zero (program hangs)

Against relibc master 69bb008af1 (the current head).

**Symptom.** A multi-threaded program that calls `posix_spawn` from one thread while another thread is creating a thread now and then hangs. The kernel logs

```
Page fault: 0000000000000000 US | ID          (RIP = 0, RSP = 0, every register 0)
kernel::context::signal:INFO -- UNHANDLED EXCEPTION ... PID <the program>
```

(or an `Invalid opcode fault`), the faulting thread is gone, and the rest of the process stays alive forever, typically with its main thread blocked in `pthread_join` (`futex`). About 5-7 % of runs of the reproducer.

**Cause.** `pthread_create` builds the new thread from handles held in the creating process's file table (`new-thread`, `current-addrspace`, `current-filetable`, `start`). The new thread's initial instruction/stack pointers and its file table are applied by the kernel when the `current-addrspace` / `current-filetable` handle is *closed*, i.e. when the last reference to the file description goes away. `fork()` therefore takes `CLONE_LOCK` for writing (and `pthread_create` for reading) so that its snapshot of the file table cannot contain those in-flight handles. `posix_spawn` takes the same kind of snapshot for the child (`dup_into_upper(b"copy")`) but does not take the lock. When a thread is being created at that moment, the child's snapshot holds a second reference to the `current-addrspace` handle, the parent's close no longer applies the registers, and the thread is started (by the following `start` write) with the initial all-zero register state.

**Fix.** Hold `CLONE_LOCK` for writing in `Sys::spawn`, exactly as `fork` does.

Related upstream items found: none about spawn vs thread creation (searched CLONE_LOCK, pthread_create fork, new thread start).

**Reproducer** (`x27_spawnpar_c`, pure C): 4 worker threads, created afresh for every round, each spawn `sh -c "echo x"` in a pipe and read its output; 40 runs of 12 rounds per boot. A run that does not finish within 30 s is a hang.

**Verification** (relibc built in CI, the repro linked against each build's libc.so as its ELF interpreter, QEMU+KVM, 6 boots per variant, 40 runs each; "series" = the other relibc patches of this collection, `spawn-cloexec`, `poll-regular-files`, `pthread-sigmask`, `spawn-child-table-size`):
- unpatched: **8 hung runs in 238**, 9 invalid-opcode and 1 zero-register fault;
- series without this patch: **12 hung runs in 240**, 13 invalid-opcode faults;
- series with this patch: **0 hung runs in 240**, 1 invalid-opcode fault (that child died, nothing hung).

Run: https://github.com/unxed/go/actions/runs/35441912130 (workflow `redox-relibc-patches`). The hang also occurs on the stock kernel of the redoxer image (that is what the "unpatched" boots run) and on kernel master (`redox-kernel-verify`, baseline).
