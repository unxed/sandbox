# The asynchronous contract and the porting rule

## The contract

- One UI thread owns every view.
- The thread-safe surface is exactly `TEventQueue.WakeUp`, `TEventQueue.PostEvent` and the timers.
- `TEventQueue.WaitForEvents(TimeoutMs)` returns on input, on a wake-up, on a due timer or after the time-out.
  - On Unix it is a pipe in the same poll.
  - On Windows it is an event object in the same wait.
  - On DOS it is a flag that the input polling reads.
- Every loop, nested modal ones too, goes through `TProgram.GetEvent`, which drains the posted events.
- Cancel tokens and progress are carried by posted events.
- On DOS, tasks are resumable objects run from Idle.
- Events address views by weak references. A gone view voids the event.

## The porting rule

- P1. The existing API (names and signatures per `docs/API-NAMES.md`, observable behaviour) is translated as it is.
  The contract only adds.
- P2. `ExecView` stays a nested loop and reaches `WaitForEvents` through `GetEvent`. A posted event reaches the
  innermost active loop. A gone addressee drops it.
- P3. Blocking operations stay synchronous; asynchronous variants are new APIs. Nothing in `GetEvent` or Idle
  blocks except `WaitForEvents`. No mutable global state is reachable from another thread.
- P4. Every `TView` is UI-thread only. State that the thread-safe surface touches is protected by a lock or an
  atomic and is listed as "difference: thread safety of ..." in `docs/API-NAMES.md`.
- P5. Where an existing API would block the UI thread on another thread or break the contract, it stays and a new
  non-blocking API is added beside it (listed as "added" in `docs/API-NAMES.md`), explained in the pull request.
- P6. Where P5 does not help, the unit is translated as the C++ has it and the one test is marked skipped with a
  link to an issue.
- P7. The units TvViews, TvWindow, TvMenus, TvApp and TvDialog pass in CI the test that `PostEvent` or `WakeUp`
  from a second thread during a modal `ExecView` is delivered, with no deadlock.
