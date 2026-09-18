// Minimal golang.org/x/sys/unix for GOOS=redox, on top of the redox port's
// syscall package (libc.so.6 = relibc) and, for what syscall does not export,
// direct libc calls through the runtime's sysvicall6 (the way x/sys/unix does on
// Solaris). Only what f4 and its dependency graph use; grown from CI errors.

//go:build redox && amd64

package unix

import (
	"syscall"
	"unsafe"
)

type (
	Errno    = syscall.Errno
	Signal   = syscall.Signal
	Stat_t   = syscall.Stat_t
	Timespec = syscall.Timespec
	Timeval  = syscall.Timeval
	Rlimit   = syscall.Rlimit
	Termios  = syscall.Termios
	Flock_t  = syscall.Flock_t
)

type Winsize struct {
	Row    uint16
	Col    uint16
	Xpixel uint16
	Ypixel uint16
}

// relibc: struct pollfd { int fd; short events; short revents; }
type PollFd struct {
	Fd      int32
	Events  int16
	Revents int16
}

type libcFunc uintptr

// Implemented in asm_redox_amd64.s (jumps into the runtime).
func sysvicall6(fn, nargs, a1, a2, a3, a4, a5, a6 uintptr) (r1, r2 uintptr, err Errno)
func rawSysvicall6(fn, nargs, a1, a2, a3, a4, a5, a6 uintptr) (r1, r2 uintptr, err Errno)

//go:cgo_import_dynamic libc_ioctl ioctl "libc.so.6"
//go:cgo_import_dynamic libc_fcntl fcntl "libc.so.6"
//go:cgo_import_dynamic libc_getpgid getpgid "libc.so.6"
//go:cgo_import_dynamic libc_poll poll "libc.so.6"
//go:cgo_import_dynamic libc_mmap mmap "libc.so.6"
//go:cgo_import_dynamic libc_munmap munmap "libc.so.6"
//go:cgo_import_dynamic libc_mprotect mprotect "libc.so.6"
//go:cgo_import_dynamic libc_fchmodat fchmodat "libc.so.6"
//go:cgo_import_dynamic libc_utimensat utimensat "libc.so.6"
//go:cgo_import_dynamic libc_setsockopt setsockopt "libc.so.6"
//go:cgo_import_dynamic libc_flock flock "libc.so.6"
//go:cgo_import_dynamic libc_mkfifo mkfifo "libc.so.6"
//go:cgo_import_dynamic libc_openpty openpty "libc.so.6"

//go:linkname libc_ioctl libc_ioctl
//go:linkname libc_fcntl libc_fcntl
//go:linkname libc_getpgid libc_getpgid
//go:linkname libc_poll libc_poll
//go:linkname libc_mmap libc_mmap
//go:linkname libc_munmap libc_munmap
//go:linkname libc_mprotect libc_mprotect
//go:linkname libc_fchmodat libc_fchmodat
//go:linkname libc_utimensat libc_utimensat
//go:linkname libc_setsockopt libc_setsockopt
//go:linkname libc_flock libc_flock
//go:linkname libc_mkfifo libc_mkfifo
//go:linkname libc_openpty libc_openpty

var (
	libc_ioctl,
	libc_fcntl,
	libc_getpgid,
	libc_poll,
	libc_mmap,
	libc_munmap,
	libc_mprotect,
	libc_fchmodat,
	libc_utimensat,
	libc_setsockopt,
	libc_flock,
	libc_mkfifo,
	libc_openpty libcFunc
)

func fn(f *libcFunc) uintptr { return uintptr(unsafe.Pointer(f)) }

func errnoErr(e Errno) error {
	if e == 0 {
		return nil
	}
	return e
}

// callErr: libc int-returning calls fail with -1; errno alone is not a reliable
// signal (the runtime clears it before the call and reads it after).
func callErr(r uintptr, e Errno) error {
	if int32(r) == -1 {
		if e == 0 {
			e = syscall.EIO
		}
		return e
	}
	return nil
}

func BytePtrFromString(s string) (*byte, error) { return syscall.BytePtrFromString(s) }

func ByteSliceToString(b []byte) string {
	for i, c := range b {
		if c == 0 {
			return string(b[:i])
		}
	}
	return string(b)
}

func Getpagesize() int { return syscall.Getpagesize() }

// ---- thin wrappers over package syscall ----

func Open(path string, mode int, perm uint32) (int, error) { return syscall.Open(path, mode, perm) }
func Close(fd int) error                                   { return syscall.Close(fd) }
func Read(fd int, p []byte) (int, error)                   { return syscall.Read(fd, p) }
func Write(fd int, p []byte) (int, error)                  { return syscall.Write(fd, p) }
func Dup2(oldfd, newfd int) error                          { return syscall.Dup2(oldfd, newfd) }
func Kill(pid int, sig Signal) error                       { return syscall.Kill(pid, sig) }
func Access(path string, mode uint32) error                { return syscall.Access(path, mode) }
func Fstat(fd int, st *Stat_t) error                       { return syscall.Fstat(fd, st) }
func Stat(path string, st *Stat_t) error                   { return syscall.Stat(path, st) }
func Lstat(path string, st *Stat_t) error                  { return syscall.Lstat(path, st) }
func SetNonblock(fd int, nb bool) error                    { return syscall.SetNonblock(fd, nb) }
func Getrlimit(which int, lim *Rlimit) error               { return syscall.Getrlimit(which, lim) }
func Munmap(b []byte) error                                { return syscall.Munmap(b) }
func FcntlFlock(fd uintptr, cmd int, lk *Flock_t) error    { return syscall.FcntlFlock(fd, cmd, lk) }

func Mmap(fd int, offset int64, length int, prot int, flags int) ([]byte, error) {
	return syscall.Mmap(fd, offset, length, prot, flags)
}

func NsecToTimeval(nsec int64) Timeval {
	sec := nsec / 1e9
	usec := (nsec % 1e9) / 1e3
	if usec < 0 {
		usec += 1e6
		sec--
	}
	return Timeval{Sec: sec, Usec: int32(usec)}
}

func NsecToTimespec(nsec int64) Timespec {
	sec := nsec / 1e9
	n := nsec % 1e9
	if n < 0 {
		n += 1e9
		sec--
	}
	return Timespec{Sec: sec, Nsec: n}
}

// ---- direct libc calls ----

func ioctl(fd int, req uint, arg uintptr) error {
	r, _, e := rawSysvicall6(fn(&libc_ioctl), 3, uintptr(fd), uintptr(req), arg, 0, 0, 0)
	return callErr(r, e)
}

func IoctlGetInt(fd int, req uint) (int, error) {
	var v int32
	if err := ioctl(fd, req, uintptr(unsafe.Pointer(&v))); err != nil {
		return 0, err
	}
	return int(v), nil
}

func IoctlSetInt(fd int, req uint, value int) error {
	v := int32(value)
	return ioctl(fd, req, uintptr(unsafe.Pointer(&v)))
}

func IoctlGetWinsize(fd int, req uint) (*Winsize, error) {
	var ws Winsize
	if err := ioctl(fd, req, uintptr(unsafe.Pointer(&ws))); err != nil {
		return nil, err
	}
	return &ws, nil
}

func IoctlSetWinsize(fd int, req uint, value *Winsize) error {
	return ioctl(fd, req, uintptr(unsafe.Pointer(value)))
}

func IoctlGetTermios(fd int, req uint) (*Termios, error) {
	var t Termios
	if err := ioctl(fd, req, uintptr(unsafe.Pointer(&t))); err != nil {
		return nil, err
	}
	return &t, nil
}

func IoctlSetTermios(fd int, req uint, value *Termios) error {
	return ioctl(fd, req, uintptr(unsafe.Pointer(value)))
}

func FcntlInt(fd uintptr, cmd, arg int) (int, error) {
	r, _, e := rawSysvicall6(fn(&libc_fcntl), 3, fd, uintptr(cmd), uintptr(arg), 0, 0, 0)
	if err := callErr(r, e); err != nil {
		return -1, err
	}
	return int(int32(r)), nil
}

func Getpgid(pid int) (int, error) {
	r, _, e := rawSysvicall6(fn(&libc_getpgid), 1, uintptr(pid), 0, 0, 0, 0, 0)
	if err := callErr(r, e); err != nil {
		return -1, err
	}
	return int(int32(r)), nil
}

func Poll(fds []PollFd, timeout int) (int, error) {
	var p unsafe.Pointer
	if len(fds) > 0 {
		p = unsafe.Pointer(&fds[0])
	}
	r, _, e := sysvicall6(fn(&libc_poll), 3, uintptr(p), uintptr(len(fds)), uintptr(timeout), 0, 0, 0)
	if err := callErr(r, e); err != nil {
		return -1, err
	}
	return int(int32(r)), nil
}

func MmapPtr(fd int, offset int64, addr unsafe.Pointer, length uintptr, prot int, flags int) (unsafe.Pointer, error) {
	r, _, e := sysvicall6(fn(&libc_mmap), 6, uintptr(addr), length, uintptr(prot), uintptr(flags), uintptr(fd), uintptr(offset))
	if r == ^uintptr(0) {
		if e == 0 {
			e = syscall.EIO
		}
		return nil, e
	}
	return unsafe.Pointer(r), nil
}

func MunmapPtr(addr unsafe.Pointer, length uintptr) error {
	r, _, e := sysvicall6(fn(&libc_munmap), 2, uintptr(addr), length, 0, 0, 0, 0)
	return callErr(r, e)
}

func Mprotect(b []byte, prot int) error {
	var p unsafe.Pointer
	if len(b) > 0 {
		p = unsafe.Pointer(&b[0])
	}
	r, _, e := sysvicall6(fn(&libc_mprotect), 3, uintptr(p), uintptr(len(b)), uintptr(prot), 0, 0, 0)
	return callErr(r, e)
}

func Fchmodat(dirfd int, path string, mode uint32, flags int) error {
	p, err := syscall.BytePtrFromString(path)
	if err != nil {
		return err
	}
	r, _, e := sysvicall6(fn(&libc_fchmodat), 4, uintptr(dirfd), uintptr(unsafe.Pointer(p)), uintptr(mode), uintptr(flags), 0, 0)
	return callErr(r, e)
}

func Lutimes(path string, tv []Timeval) error {
	if len(tv) != 2 {
		return syscall.EINVAL
	}
	ts := [2]Timespec{
		{Sec: tv[0].Sec, Nsec: int64(tv[0].Usec) * 1000},
		{Sec: tv[1].Sec, Nsec: int64(tv[1].Usec) * 1000},
	}
	p, err := syscall.BytePtrFromString(path)
	if err != nil {
		return err
	}
	fdcwd := AT_FDCWD
	r, _, e := sysvicall6(fn(&libc_utimensat), 4, uintptr(fdcwd), uintptr(unsafe.Pointer(p)), uintptr(unsafe.Pointer(&ts[0])), uintptr(AT_SYMLINK_NOFOLLOW), 0, 0)
	return callErr(r, e)
}

func SetsockoptInt(fd, level, opt int, value int) error {
	v := int32(value)
	r, _, e := sysvicall6(fn(&libc_setsockopt), 5, uintptr(fd), uintptr(level), uintptr(opt), uintptr(unsafe.Pointer(&v)), 4, 0)
	return callErr(r, e)
}

func Flock(fd int, how int) error {
	r, _, e := sysvicall6(fn(&libc_flock), 2, uintptr(fd), uintptr(how), 0, 0, 0, 0)
	return callErr(r, e)
}

func Mkfifo(path string, mode uint32) error {
	p, err := syscall.BytePtrFromString(path)
	if err != nil {
		return err
	}
	r, _, e := sysvicall6(fn(&libc_mkfifo), 2, uintptr(unsafe.Pointer(p)), uintptr(mode), 0, 0, 0, 0)
	return callErr(r, e)
}

// Openpty is libc's openpty(3) with no name/termios/winsize: it returns the master
// and slave descriptors of a new pseudo-terminal (neither is close-on-exec).
func Openpty() (master, slave int, err error) {
	var m, sl int32
	r, _, e := sysvicall6(fn(&libc_openpty), 5, uintptr(unsafe.Pointer(&m)), uintptr(unsafe.Pointer(&sl)), 0, 0, 0, 0)
	if err := callErr(r, e); err != nil {
		return -1, -1, err
	}
	return int(m), int(sl), nil
}
