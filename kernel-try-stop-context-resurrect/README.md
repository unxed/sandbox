# redox kernel: try_stop_context must not resurrect a dead context (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/kernel (patch made against master 2d2eef740a).

    git am 0001-proc-don-t-resurrect-a-context-that-died-while-it-wa.patch

(checked with `git am` on that commit in a scratch repo, alone and together with the other two kernel patches of this series (`git am -3`)). Then push to your GitLab fork and open an MR; use `ISSUE.md` for the issue text and the commit message as the MR description.

Verification: https://github.com/unxed/go/actions/runs/35438031754 and https://github.com/unxed/go/actions/runs/35438532706
Workflow, scripts and the debug ring patch: https://github.com/unxed/go/tree/golang-1.26-redox/.github/redox/kernel
