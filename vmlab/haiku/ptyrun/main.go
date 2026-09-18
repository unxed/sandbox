// ptyrun runs a command on a Haiku pseudo-terminal and captures what it draws.
// Same steps and output format as f4-redox/harness/ptyrun (so the same
// render_screens.py replays it), but the pty is allocated the way Haiku's own
// libroot does it, with every step reported so a failure points at the step.
//
//	ptyrun -cols 100 -rows 30 -script 'wait:3000,snap:start,key:\e[B,wait:500,snap:down' -- cmd args
//
// Steps: wait:MS  key:TEXT (\e \r \n \t \\ \xHH escapes)  snap:NAME
// A snap prints the bytes the child wrote since the previous snap as base64
// between markers on stdout.
//
// Haiku's pty (src/system/libroot/posix/stdlib/pty.cpp in haiku/haiku):
// posix_openpt = open("/dev/ptmx"); grantpt = ioctl(B_IOCTL_GRANT_TTY);
// unlockpt = nothing; ptsname = ioctl(B_IOCTL_GET_TTY_INDEX) ->
// /dev/tt/<'p'+idx/16><hex idx%16>; both ioctls are TCGETA(0x8000)+32/+33.
package main

import (
	"encoding/base64"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

const (
	bIoctlGetTTYIndex = 0x8020
	bIoctlGrantTTY    = 0x8021
)

var (
	mu  sync.Mutex
	buf []byte
	pos int
)

func say(format string, a ...any) { fmt.Printf("PTYRUN "+format+"\n", a...) }

func unescape(s string) []byte {
	var out []byte
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c != '\\' || i+1 >= len(s) {
			out = append(out, c)
			continue
		}
		i++
		switch s[i] {
		case 'e':
			out = append(out, 0x1b)
		case 'r':
			out = append(out, '\r')
		case 'n':
			out = append(out, '\n')
		case 't':
			out = append(out, '\t')
		case '\\':
			out = append(out, '\\')
		case 'x':
			if i+2 < len(s) {
				if v, err := strconv.ParseUint(s[i+1:i+3], 16, 8); err == nil {
					out = append(out, byte(v))
					i += 2
				}
			}
		default:
			out = append(out, '\\', s[i])
		}
	}
	return out
}

// respond answers the usual terminal queries so a program that waits for
// replies does not sit in its timeouts.
func respond(master *os.File, rows, cols int, data []byte) {
	type q struct{ pat, reply string }
	qs := []q{
		{"\x1b[c", "\x1b[?62;1;2;6;9;15;22c"},
		{"\x1b[0c", "\x1b[?62;1;2;6;9;15;22c"},
		{"\x1b[>c", "\x1b[>0;10;1c"},
		{"\x1b[>0c", "\x1b[>0;10;1c"},
		{"\x1b[5n", "\x1b[0n"},
		{"\x1b[6n", "\x1b[1;1R"},
		{"\x1b[?6n", "\x1b[?1;1;1R"},
		{"\x1b[?u", "\x1b[?0u"},
		{"\x1b[18t", fmt.Sprintf("\x1b[8;%d;%dt", rows, cols)},
		{"\x1b[14t", fmt.Sprintf("\x1b[4;%d;%dt", rows*18, cols*9)},
		{"\x1b]10;?\x07", "\x1b]10;rgb:cccc/cccc/cccc\x07"},
		{"\x1b]11;?\x07", "\x1b]11;rgb:0000/0000/0000\x07"},
		{"\x1b]10;?\x1b\\", "\x1b]10;rgb:cccc/cccc/cccc\x1b\\"},
		{"\x1b]11;?\x1b\\", "\x1b]11;rgb:0000/0000/0000\x1b\\"},
	}
	s := string(data)
	for _, x := range qs {
		for i := 0; i < strings.Count(s, x.pat); i++ {
			master.Write([]byte(x.reply))
		}
	}
	// DECRQM: CSI ? N $ p  ->  CSI ? N ; 2 $ y (reset)
	for i := 0; i+3 < len(s); i++ {
		if s[i] == 0x1b && strings.HasPrefix(s[i:], "\x1b[?") {
			j := i + 3
			for j < len(s) && s[j] >= '0' && s[j] <= '9' {
				j++
			}
			if j+1 < len(s) && s[j] == '$' && s[j+1] == 'p' && j > i+3 {
				master.Write([]byte("\x1b[?" + s[i+3:j] + ";2$y"))
			}
		}
	}
}

func snap(tag, name string) {
	mu.Lock()
	chunk := append([]byte(nil), buf[pos:]...)
	pos = len(buf)
	mu.Unlock()
	fmt.Printf("=====PTYSNAP %s %s BEGIN bytes=%d=====\n", tag, name, len(chunk))
	enc := base64.StdEncoding.EncodeToString(chunk)
	for len(enc) > 0 {
		n := 100
		if n > len(enc) {
			n = len(enc)
		}
		fmt.Println(enc[:n])
		enc = enc[n:]
	}
	fmt.Printf("=====PTYSNAP %s %s END=====\n", tag, name)
}

// openPTY allocates a pty the way Haiku's libroot does and reports each step.
func openPTY(rows, cols int) (mfd, sfd int, slaveName string, err error) {
	mfd, err = unix.Open("/dev/ptmx", unix.O_RDWR|unix.O_NOCTTY|unix.O_CLOEXEC, 0)
	say("open /dev/ptmx -> fd=%d err=%v", mfd, err)
	if err != nil {
		return
	}
	if err = unix.IoctlSetInt(mfd, bIoctlGrantTTY, 0); err != nil {
		say("ioctl B_IOCTL_GRANT_TTY (0x%x) -> err=%v", bIoctlGrantTTY, err)
		return
	}
	say("ioctl B_IOCTL_GRANT_TTY -> ok")
	var idx int
	if idx, err = unix.IoctlGetInt(mfd, bIoctlGetTTYIndex); err != nil {
		say("ioctl B_IOCTL_GET_TTY_INDEX (0x%x) -> err=%v", bIoctlGetTTYIndex, err)
		return
	}
	slaveName = fmt.Sprintf("/dev/tt/%c%x", 'p'+idx/16, idx%16)
	say("ioctl B_IOCTL_GET_TTY_INDEX -> %d, slave %s", idx, slaveName)
	ws := unix.Winsize{Row: uint16(rows), Col: uint16(cols)}
	if e := unix.IoctlSetWinsize(mfd, unix.TIOCSWINSZ, &ws); e != nil {
		say("ioctl TIOCSWINSZ on master -> err=%v (not fatal)", e)
	}
	sfd, err = unix.Open(slaveName, unix.O_RDWR|unix.O_NOCTTY|unix.O_CLOEXEC, 0)
	say("open %s -> fd=%d err=%v", slaveName, sfd, err)
	if err != nil {
		if ents, e := os.ReadDir("/dev/tt"); e == nil {
			var names []string
			for _, en := range ents {
				names = append(names, en.Name())
			}
			say("/dev/tt has %d entries: %v", len(names), names)
		} else {
			say("ReadDir /dev/tt: %v", e)
		}
	}
	return
}

func main() {
	cols := flag.Int("cols", 100, "terminal columns")
	rows := flag.Int("rows", 30, "terminal rows")
	script := flag.String("script", "wait:3000,snap:end", "steps")
	tag := flag.String("tag", "run", "label for the snapshots")
	flag.Parse()
	argv := flag.Args()
	if len(argv) == 0 {
		fmt.Println("usage: ptyrun [flags] -- cmd args")
		os.Exit(2)
	}

	mfd, sfd, slaveName, err := openPTY(*rows, *cols)
	if err != nil {
		say("pty allocation FAILED: %v", err)
		os.Exit(1)
	}
	master := os.NewFile(uintptr(mfd), "ptmx")
	slave := os.NewFile(uintptr(sfd), slaveName)
	say("pty ready: %s", slaveName)

	start := func(attr *syscall.SysProcAttr) (*exec.Cmd, error) {
		cmd := exec.Command(argv[0], argv[1:]...)
		cmd.Stdin, cmd.Stdout, cmd.Stderr = slave, slave, slave
		cmd.Env = append(os.Environ(), "TERM=xterm-256color", "COLORTERM=truecolor",
			"LINES="+strconv.Itoa(*rows), "COLUMNS="+strconv.Itoa(*cols))
		cmd.SysProcAttr = attr
		return cmd, cmd.Start()
	}
	cmd, err := start(&syscall.SysProcAttr{Setsid: true, Setctty: true})
	if err != nil {
		say("start with Setsid+Setctty failed: %v", err)
		cmd, err = start(&syscall.SysProcAttr{Setsid: true})
	}
	if err != nil {
		say("start with Setsid failed: %v", err)
		cmd, err = start(nil)
	}
	if err != nil {
		say("start failed: %v", err)
		os.Exit(1)
	}
	say("child pid %d", cmd.Process.Pid)
	slave.Close()

	go func() {
		b := make([]byte, 65536)
		for {
			k, err := master.Read(b)
			if k > 0 {
				mu.Lock()
				buf = append(buf, b[:k]...)
				mu.Unlock()
				respond(master, *rows, *cols, b[:k])
			}
			if err != nil {
				say("master read ended: %v", err)
				return
			}
		}
	}()
	exited := make(chan error, 1)
	go func() { exited <- cmd.Wait() }()

	for _, step := range strings.Split(*script, ",") {
		name, arg, _ := strings.Cut(step, ":")
		switch name {
		case "wait":
			ms, _ := strconv.Atoi(arg)
			select {
			case err := <-exited:
				say("child exited early: %v", err)
				exited <- err
			case <-time.After(time.Duration(ms) * time.Millisecond):
			}
		case "key":
			if _, err := master.Write(unescape(arg)); err != nil {
				say("write key: %v", err)
			}
		case "snap":
			snap(*tag, arg)
		}
	}
	select {
	case err := <-exited:
		say("child finished: %v", err)
	default:
		say("child still running, killing")
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		_ = cmd.Process.Kill()
	}
	say("DONE")
	os.Exit(0)
}
