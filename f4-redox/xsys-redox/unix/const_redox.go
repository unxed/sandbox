//go:build redox && amd64

package unix

// Values from relibc (src/header/poll, fcntl, unistd, termios, sys_ioctl).
// Constants that the redox syscall package already has are aliased by
// zconst_redox_amd64.go (generated) instead.
const (
	POLLIN     = 0x1
	POLLPRI    = 0x2
	POLLOUT    = 0x4
	POLLERR    = 0x8
	POLLHUP    = 0x10
	POLLNVAL   = 0x20
	POLLRDNORM = 0x40
	POLLRDBAND = 0x80
	POLLWRNORM = 0x100
	POLLWRBAND = 0x200

	AT_FDCWD            = -0x64
	AT_SYMLINK_NOFOLLOW = 0x200
	AT_REMOVEDIR        = 0x200
	AT_SYMLINK_FOLLOW   = 0x2000
	AT_EACCESS          = 0x400
	AT_EMPTY_PATH       = 0x4000

	F_OK = 0x0
	X_OK = 0x1
	W_OK = 0x2
	R_OK = 0x4

	TCGETS  = 0x5401
	TCSETS  = 0x5402
	TCSETSW = 0x5403
	TCSETSF = 0x5404
	FIONREAD = 0x541b
	FIONBIO  = 0x5421
)
