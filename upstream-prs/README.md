# upstream-prs

CI-only checks for branches that carry f4's fork changes back to upstream
projects (mholt/archives, bodgit/sevenzip, ulikunitz/xz, go-webgpu/goffi,
mikkyang/id3-go, godesktop/xkb-go).

Run `.github/workflows/upstream-pr-test.yml` by hand with the fork repository,
the branch, and the go test arguments. It runs `gofmt -l`, `go vet` and
`go test` on the branch as it is, with the Go version from its go.mod.
