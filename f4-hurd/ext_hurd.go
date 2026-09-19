// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package syscall

import "unsafe"

// Additional libc entry points for code outside the standard library that has to
// talk to libc on Hurd (the golang.org/x/sys/unix stand-in used to build f4).
// Dynamic imports only link reliably from this package, so they live here and are
// reached through the single pushed linkname extCall.

//go:cgo_import_dynamic libc_Tcgetattr tcgetattr "libc.so.0.3"
//go:cgo_import_dynamic libc_Tcsetattr tcsetattr "libc.so.0.3"
//go:cgo_import_dynamic libc_Ioctl ioctl "libc.so.0.3"
//go:cgo_import_dynamic libc_Poll poll "libc.so.0.3"
//go:cgo_import_dynamic libc_Mprotect mprotect "libc.so.0.3"
//go:cgo_import_dynamic libc_Fchmodat fchmodat "libc.so.0.3"
//go:cgo_import_dynamic libc_Flock flock "libc.so.0.3"
//go:cgo_import_dynamic libc_Getpgid getpgid "libc.so.0.3"
//go:cgo_import_dynamic libc_PosixOpenpt posix_openpt "libc.so.0.3"
//go:cgo_import_dynamic libc_Grantpt grantpt "libc.so.0.3"
//go:cgo_import_dynamic libc_Unlockpt unlockpt "libc.so.0.3"
//go:cgo_import_dynamic libc_PtsnameR ptsname_r "libc.so.0.3"

//go:linkname libc_Tcgetattr libc_Tcgetattr
//go:linkname libc_Tcsetattr libc_Tcsetattr
//go:linkname libc_Ioctl libc_Ioctl
//go:linkname libc_Poll libc_Poll
//go:linkname libc_Mprotect libc_Mprotect
//go:linkname libc_Fchmodat libc_Fchmodat
//go:linkname libc_Flock libc_Flock
//go:linkname libc_Getpgid libc_Getpgid
//go:linkname libc_PosixOpenpt libc_PosixOpenpt
//go:linkname libc_Grantpt libc_Grantpt
//go:linkname libc_Unlockpt libc_Unlockpt
//go:linkname libc_PtsnameR libc_PtsnameR

var (
	libc_Tcgetattr,
	libc_Tcsetattr,
	libc_Ioctl,
	libc_Poll,
	libc_Mprotect,
	libc_Fchmodat,
	libc_Flock,
	libc_Getpgid,
	libc_PosixOpenpt,
	libc_Grantpt,
	libc_Unlockpt,
	libc_PtsnameR libcFunc
)

// Function indexes for extCall.
const (
	extTcgetattr = iota
	extTcsetattr
	extIoctl
	extPoll
	extMprotect
	extFcntl
	extFchmodat
	extUtimensat
	extFlock
	extMmap
	extGetpgid
	extPosixOpenpt
	extGrantpt
	extUnlockpt
	extPtsnameR
)

// extCall calls the libc function selected by idx (an ext* constant) and
// returns its raw results and errno. Pushed to golang.org/x/sys/unix.
//
// The address of a dynamic import can only be taken in code (a data table of
// them would need data relocations against SDYNIMPORT symbols, which the
// linker does not support), hence the switch.
//
//go:linkname extCall
func extCall(idx, nargs, a1, a2, a3, a4, a5, a6 uintptr) (r1, r2 uintptr, err Errno) {
	switch idx {
	case extTcgetattr:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Tcgetattr)), nargs, a1, a2, a3, a4, a5, a6)
	case extTcsetattr:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Tcsetattr)), nargs, a1, a2, a3, a4, a5, a6)
	case extIoctl:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Ioctl)), nargs, a1, a2, a3, a4, a5, a6)
	case extPoll:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Poll)), nargs, a1, a2, a3, a4, a5, a6)
	case extMprotect:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Mprotect)), nargs, a1, a2, a3, a4, a5, a6)
	case extFcntl:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Fcntl)), nargs, a1, a2, a3, a4, a5, a6)
	case extFchmodat:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Fchmodat)), nargs, a1, a2, a3, a4, a5, a6)
	case extUtimensat:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Utimensat)), nargs, a1, a2, a3, a4, a5, a6)
	case extFlock:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Flock)), nargs, a1, a2, a3, a4, a5, a6)
	case extMmap:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Mmap)), nargs, a1, a2, a3, a4, a5, a6)
	case extGetpgid:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Getpgid)), nargs, a1, a2, a3, a4, a5, a6)
	case extPosixOpenpt:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_PosixOpenpt)), nargs, a1, a2, a3, a4, a5, a6)
	case extGrantpt:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Grantpt)), nargs, a1, a2, a3, a4, a5, a6)
	case extUnlockpt:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_Unlockpt)), nargs, a1, a2, a3, a4, a5, a6)
	case extPtsnameR:
		return sysvicall6(uintptr(unsafe.Pointer(&libc_PtsnameR)), nargs, a1, a2, a3, a4, a5, a6)
	}
	return 0, 0, ENOSYS
}
