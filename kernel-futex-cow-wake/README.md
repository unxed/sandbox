# redox kernel: wake futex waiters when a CoW fault moves their page (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/kernel (patch made against master 2d2eef740a).

    git am 0001-futex-wake-the-waiters-of-a-frame-when-a-copy-on-wri.patch

(checked with `git am` on that commit in a scratch repo, alone and together with `../kernel-forcekill-lost-wakeup/`'s patch using `git am -3`). Then push to your GitLab fork and open an MR; use `ISSUE.md` for the issue text and the commit message as the MR description.

Verification: https://github.com/unxed/go/actions/runs/35428992551
Workflow and scripts: https://github.com/unxed/go/tree/golang-1.26-redox/.github/redox/kernel
