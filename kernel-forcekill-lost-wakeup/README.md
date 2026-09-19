# redox kernel: lost ForceKill wakeup (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/kernel (patch made against master 2d2eef740a, v3).

    git am 0001-futex-don-t-sleep-on-an-untimed-wait-when-the-contex.patch

(checked with `git am` on that commit in a scratch repo). Then push the branch to your GitLab fork and
open an MR; use `ISSUE.md` for the issue text and the commit message as the MR description.

Verification (kernel rebuilt in CI, unpatched vs patched, pure-C repro on Redox under QEMU+KVM):
- v3 (this patch): https://github.com/unxed/go/actions/runs/35410254114 - hangs of the exit repro, `exit()` / `_exit`:
  patched 0/60 and 0/30 (the other patched repeat lost its x17 run to the unrelated panic below);
  stock image kernel 3/60 and 0/30; kernel master, unpatched: 22/60 and 8/30 (repeat 1), 6/60 and 4/30 (repeat 2).
- v2 (block() refused sigkilled contexts, superseded): https://github.com/unxed/go/actions/runs/35403271670
  (14/60 stock, 8/60 master, 0/60 patched).
- Why v3: v2 broke the invariant of `UserInner::call_inner` (block, then direct-switch to the handler);
  in a concurrent `posix_spawn` stress the kernel then hit `unreachable!()` at syscall/process.rs:83 in
  2/2 runs (https://github.com/unxed/go/actions/runs/35409694501). That panic is NOT caused by the patch:
  it was seen again with v3 (1/2) and, as a silent freeze after "UNHANDLED EXCEPTION" of a broken spawned
  child, on the stock kernel (1/2) - a separate pre-existing kernel bug, see
  https://github.com/unxed/go/blob/golang-1.26-redox/.github/redox/upstream/README.md (#9).
Workflow and scripts: https://github.com/unxed/go/tree/golang-1.26-redox/.github/redox/kernel
