# redox kernel: lost ForceKill wakeup (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/kernel (patch made against master 2d2eef740a).

    git am 0001-context-don-t-lose-a-ForceKill-wakeup-when-a-context.patch

(checked with `git am` on that commit). Then push the branch to your GitLab fork and open an MR;
use `ISSUE.md` for the issue text and the commit message as the MR description.

Verification (kernel rebuilt in CI, unpatched vs patched, pure-C repro on Redox under QEMU):
https://github.com/unxed/go/actions/runs/35395324027  (workflow redox-kernel-verify)
Workflow and scripts: https://github.com/unxed/go/tree/golang-1.26-redox/.github/redox/kernel
