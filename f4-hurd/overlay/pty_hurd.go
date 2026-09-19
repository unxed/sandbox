//go:build hurd

package terminal

import (
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/unxed/vtui"
	"golang.org/x/sys/unix"
)

// PTY handles pseudo-terminal allocation and process execution on GNU/Hurd.
//
// Hurd has BSD-style ptys: the master is /dev/ptyXN, the slave /dev/ttyXN
// (no /dev/ptmx, no /dev/pts). glibc's posix_openpt/grantpt/unlockpt/ptsname
// find a free pair. Measured on real Hurd (unxed/debian-hurd poc/pty_poc.c):
// the master is non-blocking and pollable, TIOCSWINSZ works on the master,
// a child that calls setsid and TIOCSCTTY on the slave gets it as its
// controlling terminal. TIOCGPGRP fails on the master, so IsBusy asks the slave.
type PTY struct {
	Master    *os.File
	Slave     *os.File
	masterFd  int
	slaveFd   int
	Cmd       *exec.Cmd
	closed    bool
	closeOnce sync.Once
	shellPgrp int
}

func NewPTY() (*PTY, error) {
	// O_CLOEXEC on both ends for the reason given in pty_linux.go: without it
	// the shell inherits a copy of its own master and never sees the hangup.
	masterFd, slaveName, err := unix.Openpty(unix.O_RDWR | unix.O_NOCTTY | unix.O_CLOEXEC)
	if err != nil {
		return nil, err
	}
	unix.CloseOnExec(masterFd)
	// Non-blocking *before* os.NewFile, so the runtime poller owns the fd and
	// Close from another goroutine interrupts a blocked Read (see pty_linux.go).
	if err := unix.SetNonblock(masterFd, true); err != nil {
		unix.Close(masterFd)
		return nil, err
	}
	master := os.NewFile(uintptr(masterFd), "pty-master")

	slaveFd, err := unix.Open(slaveName, unix.O_RDWR|unix.O_NOCTTY|unix.O_CLOEXEC, 0)
	if err != nil {
		master.Close()
		return nil, err
	}
	slave := os.NewFile(uintptr(slaveFd), slaveName)

	p := &PTY{Master: master, Slave: slave, masterFd: masterFd, slaveFd: slaveFd}
	registerPTYOpened()
	return p, nil
}

func (p *PTY) Write(b []byte) (int, error) {
	return p.Master.Write(b)
}

func (p *PTY) Read(b []byte) (int, error) {
	return p.Master.Read(b)
}

func (p *PTY) Close() error {
	var err error
	p.closeOnce.Do(func() {
		vtui.DebugLog("PTY: Closing PTY and killing child process group")
		if p.Cmd != nil && p.Cmd.Process != nil {
			// Kill the whole process group because we used Setsid
			_ = syscall.Kill(-p.Cmd.Process.Pid, syscall.SIGKILL)
			p.Cmd.Process.Kill()
		}
		if p.Master != nil {
			err = p.Master.Close()
		}
		if p.Slave != nil {
			p.Slave.Close()
		}
		p.closed = true
		registerPTYClosed()
	})
	return err
}

func (p *PTY) Wait() error {
	return p.Cmd.Wait()
}

func (p *PTY) Run(name string, args ...string) error {
	p.Cmd = exec.Command(name, args...)
	p.Cmd.Stdin = p.Slave
	p.Cmd.Stdout = p.Slave
	p.Cmd.Stderr = p.Slave
	p.Cmd.Env = TerminalChildEnv()
	p.Cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid:  true,
		Setctty: true,
	}

	p.SetSize(80, 24)

	err := p.Cmd.Start()
	if err == nil {
		p.shellPgrp, _ = unix.Getpgid(p.Cmd.Process.Pid)
	}
	return err
}

func (p *PTY) IsBusy() bool {
	if p.Slave == nil {
		return false
	}
	// Not p.Slave.Fd(): the raw descriptor is kept so os.File is not switched
	// to blocking mode behind the poller's back.
	pgrp, err := unix.IoctlGetInt(p.slaveFd, unix.TIOCGPGRP)
	if err != nil {
		return false
	}
	return pgrp != p.shellPgrp
}

func (p *PTY) SetSize(cols, rows int) {
	p.SetSizePixels(cols, rows, 0, 0)
}

// SetSizePixels also reports the size of the window in pixels, which is how
// a program in the terminal learns the shape of a character cell.
func (p *PTY) SetSizePixels(cols, rows, xpixel, ypixel int) {
	ws := &unix.Winsize{
		Row:    uint16(rows),
		Col:    uint16(cols),
		Xpixel: ptyPixels(xpixel),
		Ypixel: ptyPixels(ypixel),
	}
	_ = unix.IoctlSetWinsize(p.masterFd, unix.TIOCSWINSZ, ws)
}

func GetSystemShell() string {
	shell := os.Getenv("SHELL")
	if shell == "" {
		return "/bin/sh"
	}
	base := filepath.Base(shell)
	if base == "fish" || base == "csh" || base == "tcsh" {
		return "bash"
	}
	return shell
}
