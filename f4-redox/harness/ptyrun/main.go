// ptyrun runs a command on a Redox pseudo-terminal and captures what it draws.
//
//	ptyrun -cols 100 -rows 30 -script 'wait:3000,snap:start,key:\e[B,wait:500,snap:down' -- cmd args
//
// Steps: wait:MS  key:TEXT (\e \r \n \t \\ \xHH escapes)  snap:NAME
// A snap prints the bytes the child wrote since the previous snap as base64 between
// markers on stdout; the host side (render_screens.py) replays them cumulatively
// through a terminal emulator.
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

var (
	mu  sync.Mutex
	buf []byte
	pos int
)

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

// respond answers the usual terminal queries so a program that waits for replies
// does not sit in its timeouts.
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

	var mfd, sfd int
	var slaveName string
	openManual := func() error {
		var err error
		mfd, err = unix.Open("/scheme/pty/ptmx", unix.O_RDWR|unix.O_NOCTTY|unix.O_CLOEXEC, 0)
		if err != nil {
			return fmt.Errorf("open ptmx: %w", err)
		}
		// relibc's openpty unlocks first; on Redox TIOCGPTN fails with EIO while locked
		if err := unix.IoctlSetInt(mfd, unix.TIOCSPTLCK, 0); err != nil {
			fmt.Println("PTYRUN TIOCSPTLCK:", err)
		}
		n, err := unix.IoctlGetInt(mfd, unix.TIOCGPTN)
		if err != nil {
			return fmt.Errorf("TIOCGPTN: %w", err)
		}
		slaveName = fmt.Sprintf("/scheme/pty/%d", n)
		sfd, err = unix.Open(slaveName, unix.O_RDWR|unix.O_NOCTTY|unix.O_CLOEXEC, 0)
		if err != nil {
			return fmt.Errorf("open slave %s: %w", slaveName, err)
		}
		return nil
	}
	if err := openManual(); err != nil {
		fmt.Println("PTYRUN manual pty allocation failed:", err, "- trying libc openpty")
		var err2 error
		mfd, sfd, err2 = unix.Openpty()
		if err2 != nil {
			fmt.Println("PTYRUN openpty failed:", err2)
			os.Exit(1)
		}
		slaveName = "openpty"
	}
	ws := unix.Winsize{Row: uint16(*rows), Col: uint16(*cols)}
	if err := unix.IoctlSetWinsize(mfd, unix.TIOCSWINSZ, &ws); err != nil {
		fmt.Println("PTYRUN TIOCSWINSZ:", err)
	}
	master := os.NewFile(uintptr(mfd), "ptmx")
	slave := os.NewFile(uintptr(sfd), slaveName)
	fmt.Println("PTYRUN pty ready:", slaveName)

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
		fmt.Println("PTYRUN start with Setsid+Setctty failed:", err)
		cmd, err = start(&syscall.SysProcAttr{Setsid: true})
	}
	if err != nil {
		fmt.Println("PTYRUN start with Setsid failed:", err)
		cmd, err = start(nil)
	}
	if err != nil {
		fmt.Println("PTYRUN start failed:", err)
		os.Exit(1)
	}
	fmt.Println("PTYRUN child pid", cmd.Process.Pid)
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
				fmt.Println("PTYRUN child exited early:", err)
				exited <- err
			case <-time.After(time.Duration(ms) * time.Millisecond):
			}
		case "key":
			if _, err := master.Write(unescape(arg)); err != nil {
				fmt.Println("PTYRUN write key:", err)
			}
		case "snap":
			snap(*tag, arg)
		case "ctx":
			if data, err := os.ReadFile("/scheme/sys/context"); err == nil {
				for i, l := range strings.Split(string(data), "\n") {
					if i == 0 || strings.Contains(l, arg) {
						fmt.Println("CTX", l)
					}
				}
			}
		}
	}
	select {
	case err := <-exited:
		fmt.Println("PTYRUN child finished:", err)
	default:
		fmt.Println("PTYRUN child still running, killing")
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		_ = cmd.Process.Kill()
	}
	fmt.Println("PTYRUN DONE")
	os.Exit(0)
}
