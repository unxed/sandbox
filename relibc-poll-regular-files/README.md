# relibc: poll() fails the whole call when one descriptor is a regular file (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/relibc (patch made against master 69bb008af1).

    git am 0001-poll-report-regular-files-and-other-epoll-unwatchabl.patch

(checked with `git am` on that commit in a scratch repo; the three relibc patches in this series touch different files and apply together). Then push the branch to your GitLab fork and open an MR; use `ISSUE.md` for the issue text and the commit message as the MR description.

Verification: https://github.com/unxed/go/actions/runs/35428002403
Workflow, scripts and repros: https://github.com/unxed/go/tree/golang-1.26-redox/.github/redox
