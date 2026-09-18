# relibc: sigentry rcx clobber (for GitLab MR)

Upstream: https://gitlab.redox-os.org/redox-os/relibc (master 69bb008af1 at the time).

Apply to a relibc checkout:

    git am 0001-redox-rt-x86_64-don-t-clobber-rcx-in-__relibc_internal_sigentry.patch

Then push the branch to your GitLab fork and open an MR. Use `ISSUE.md` for the issue
(reference it from the MR) and `MR.md` as the MR description.

The same commit is on GitHub: https://github.com/unxed/relibc/tree/fix-sigentry-rcx-clobber
Verification runs (unpatched vs patched relibc, on Redox in CI): https://github.com/unxed/go/actions/runs/35387410427
