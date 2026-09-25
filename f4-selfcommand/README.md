# f4-selfcommand

Checks that `update.SelfCommand` in f4's universal Linux build starts working
copies of f4 on glibc 2.31 (Debian 11, Ubuntu 20.04), current glibc, and musl
(Alpine).

Before the fix, SelfCommand started copies through the host loader by hand
(`<ld.so> --preload <libs> /proc/self/fd/<n>`). glibc 2.31's loader rejects that
image with `loader cannot load itself`. With goffi v0.1.11 the re-exec guard is
tagged with a pid, so a copy can be started by path and runs goffi's bridge
itself.

`main.go.txt` is copied into f4's tree as `cmd/selfcommand-probe/main.go` (it
imports `internal/update`). It is built the way f4's release builds
`cmd/f4`: `-tags goffi_universal`, then `goffi-strip-interp` and
`goffi-audit`. The same binary then runs in each container.

Run: `gh workflow run f4-selfcommand.yml -R unxed/sandbox -f ref=<f4 ref>`.
