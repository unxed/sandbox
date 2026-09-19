# kernel: try_stop_context can resurrect a dead context ("entered unreachable code" in exit_this_context)

Against kernel master 2d2eef740a (the current head).

**Symptom.** Kernel panic, now and then, while processes that take an exception are being torn down (in practice: children of `posix_spawn` that die before they get anywhere):

```
KERNEL PANIC: panicked at src/syscall/process.rs:95:5:
internal error: entered unreachable code
```

`exit_this_context` ends with `context::switch(token); unreachable!();`. The switch is supposed to never come back, because the context was marked Dead first.

**Cause (traced with a lock-free per-CPU event ring in the kernel; the trace of one panic, context 1129, CPUs 0/3/2):**

```
EXCEPTION   id=1129                 (exit_this_context entered because of the fault)
EXIT_STEP   1, 2, 3                 (files closed)
DEAD_SET    id=1129                 (status = Dead { excp })
EXIT_STEP   4                       (about to switch away)
SWITCH_TO   prev=1129 next=1123     (prev status Dead, correct)
TRYSTOP_END id=1129 status=Dead saved=Runnable     <- cpu3: try_stop_context restores the saved status
PICK        1129                    (scheduler picks the "Runnable" context again)
SWITCH_TO   next=1129
EXIT_STEP   1129 5                  (context::switch returned inside exit_this_context)  -> unreachable!()
```

`try_stop_context` (used for register/env reads and writes and for the address-space change at exec) stops another context by replacing its status with a `HardBlocked { NotYetStarted }` marker, waits until `running` is false, runs its callback and then writes the previously saved status back **unconditionally**. If the context was running when it was stopped and takes an exception on its way out, `exit_this_context` replaces the marker with `Dead`, switches away, and the restore then overwrites `Dead` with the saved `Runnable` and wakes the context: it is scheduled again and resumes inside `exit_this_context`, after its final switch. (The same overwrite throws away a `ForceKill`, which sets `Runnable` + `being_sigkilled`, that arrives while the context is stopped.)

**Fix.** Restore the saved status only if the status is still the marker; otherwise leave what the context (or ForceKill) set meanwhile.

Related upstream items found: MR !663 "Drop context Arc on force kill" and !621 "Solve context leak when switching" (both merged) are about other context-lifetime problems; nothing about `try_stop_context`.

**Reproducer.** No small deterministic one; the race needs a stop of a context that is dying. Statistical: `x27_spawnpar_c` (4 threads spawning `sh`; with stock relibc some threads/children start with all registers zero or die with an invalid-opcode fault, see the relibc issue `relibc-spawn-clone-lock`, which makes them a steady source of dying contexts), boots of 40 runs on QEMU+KVM, 4 CPUs:
- unpatched master: **2 of 5 boots ended in the panic** (187 runs completed), and 2 of 3 boots in the full script;
- with this patch: **0 of 5 boots** (200 runs) and, together with the two futex patches (`kernel-forcekill-lost-wakeup`, `kernel-futex-cow-wake`), 0 of 5 boots (200 runs) and 0 of 3 in the full script.
- The event ring trace above comes from https://github.com/unxed/go/actions/runs/35437379734.

Runs: https://github.com/unxed/go/actions/runs/35438031754 (x27 only), https://github.com/unxed/go/actions/runs/35438532706 (full script: x37 crash loop, x23, x17, x34, x27). Workflow `redox-kernel-verify`.
