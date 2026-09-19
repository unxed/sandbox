// Package unix is a minimal GOOS=hurd stand-in for golang.org/x/sys/unix, which
// has no gc port for Hurd. Only the API that f4 and its dependencies use is
// provided, implemented on top of the (ported) standard syscall package.
// The CI job hurd-f4-build copies this directory over vendor/golang.org/x/sys/unix.

//go:build hurd

package unix
