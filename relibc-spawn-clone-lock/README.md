# relibc: posix_spawn: take CLONE_LOCK like fork does (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/relibc (patch made against master 69bb008af1).

    git am 0001-redox-posix_spawn-take-CLONE_LOCK-like-fork-does.patch

(checked with `git am` on that commit in a scratch repo, alone and together with the other relibc patches of this collection). Then push the branch to your GitLab fork and open an MR; use `ISSUE.md` for the issue text and the commit message as the MR description.

Verification: https://github.com/unxed/go/actions/runs/35441912130
Workflow, scripts and repros: https://github.com/unxed/go/tree/golang-1.26-redox/.github/redox
