// pollprobe: what does poll(2) say for the descriptors f4's input reader watches?
package main

import (
	"fmt"
	"os"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

func try(name string, fd int, timeoutMs int) {
	fds := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLIN}}
	t0 := time.Now()
	n, err := unix.Poll(fds, timeoutMs)
	fmt.Printf("POLLPROBE %-28s fd=%d timeout=%dms -> n=%d err=%v revents=0x%x (%v)\n", name, fd, timeoutMs, n, err, fds[0].Revents, time.Since(t0).Round(time.Millisecond))
}

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "edge" || os.Args[1] == "edgeraw" || os.Args[1] == "edgeicrnl" || os.Args[1] == "edgeopost") {
		t, _ := unix.IoctlGetTermios(0, unix.TCGETS)
		if t != nil {
			nt := *t
			nt.Lflag &^= unix.ECHO | unix.ECHONL | unix.ICANON | unix.ISIG | unix.IEXTEN
			nt.Cc[unix.VMIN] = 1
			nt.Cc[unix.VTIME] = 0
			switch os.Args[1] {
			case "edgeraw": // exactly x/term.MakeRaw
				nt.Iflag &^= unix.IGNBRK | unix.BRKINT | unix.PARMRK | unix.ISTRIP | unix.INLCR | unix.IGNCR | unix.ICRNL | unix.IXON
				nt.Oflag &^= unix.OPOST
				nt.Cflag &^= unix.CSIZE | unix.PARENB
				nt.Cflag |= unix.CS8
			case "edgeicrnl":
				nt.Iflag &^= unix.ICRNL
			case "edgeopost":
				nt.Oflag &^= unix.OPOST
			}
			fmt.Printf("EDGEPROBE mode=%s termios before=%+v after=%+v set=%v\n", os.Args[1], *t, nt, unix.IoctlSetTermios(0, unix.TCSETS, &nt))
		}
		buf := make([]byte, 64)
		try("A: poll BEFORE key arrives (key at ~1.0s)", 0, 2500)
		k, err := syscall.Read(0, buf)
		fmt.Printf("EDGEPROBE A read %d %q err=%v\n", k, buf[:max(k, 0)], err)
		time.Sleep(3500 * time.Millisecond) // key B arrives meanwhile
		try("B: poll with data ALREADY pending", 0, 1500)
		try("B2: poll again", 0, 500)
		k, err = syscall.Read(0, buf)
		fmt.Printf("EDGEPROBE B read %d %q err=%v\n", k, buf[:max(k, 0)], err)
		fmt.Println("EDGEPROBE DONE")
		os.Exit(0)
	}
	if len(os.Args) > 1 && os.Args[1] == "input" {
		// switch the terminal to raw mode like f4 does, then wait for typed bytes
		t, err := unix.IoctlGetTermios(0, unix.TCGETS)
		fmt.Println("INPUTPROBE TCGETS:", err)
		if err == nil {
			nt := *t
			nt.Lflag &^= unix.ECHO | unix.ECHONL | unix.ICANON | unix.ISIG | unix.IEXTEN
			nt.Iflag &^= unix.IGNBRK | unix.BRKINT | unix.PARMRK | unix.ISTRIP | unix.INLCR | unix.IGNCR | unix.ICRNL | unix.IXON
			nt.Cc[unix.VMIN] = 1
			nt.Cc[unix.VTIME] = 0
			fmt.Println("INPUTPROBE TCSETS raw:", unix.IoctlSetTermios(0, unix.TCSETS, &nt))
		}
		// (a) a blocking read in a goroutine, (b) poll in parallel
		got := make(chan string, 4)
		go func() {
			buf := make([]byte, 64)
			for i := 0; i < 3; i++ {
				k, err := syscall.Read(0, buf)
				got <- fmt.Sprintf("read %d bytes %q err=%v", k, buf[:max(k, 0)], err)
			}
		}()
		for i := 0; i < 3; i++ {
			try("stdin poll while a read waits", 0, 1500)
			select {
			case m := <-got:
				fmt.Println("INPUTPROBE (blocking read) ", m)
			default:
			}
		}
		select {
		case m := <-got:
			fmt.Println("INPUTPROBE (blocking read, late) ", m)
		case <-time.After(1 * time.Second):
			fmt.Println("INPUTPROBE blocking read still waiting")
		}
		fmt.Println("INPUTPROBE DONE")
		os.Exit(0)
	}
	try("stdin (tty slave)", 0, 300)
	var p [2]int
	if err := syscall.Pipe(p[:]); err != nil {
		fmt.Println("POLLPROBE pipe:", err)
	} else {
		try("pipe read end, empty", p[0], 300)
		syscall.Write(p[1], []byte("x"))
		try("pipe read end, data", p[0], 300)
	}
	f, err := os.Open("/tmp/demo/readme.txt")
	if err == nil {
		try("regular file", int(f.Fd()), 300)
	}
	try("stdin again", 0, 300)
	// also two fds at once, as vtinput does (stdin + stop pipe)
	fds := []unix.PollFd{{Fd: 0, Events: unix.POLLIN}, {Fd: int32(p[0]), Events: unix.POLLIN}}
	n, err := unix.Poll(fds, 300)
	fmt.Printf("POLLPROBE stdin+pipe -> n=%d err=%v rev=[0x%x 0x%x]\n", n, err, fds[0].Revents, fds[1].Revents)
	// raw termios on stdin
	t, err := unix.IoctlGetTermios(0, unix.TCGETS)
	fmt.Printf("POLLPROBE TCGETS on stdin: err=%v\n", err)
	if err == nil {
		fmt.Printf("POLLPROBE termios: %+v\n", *t)
	}
	// directory listing the way f4's OSVFS.ReadDir does it
	ents, err := os.ReadDir("/tmp/demo")
	fmt.Printf("DIRPROBE os.ReadDir(/tmp/demo): %d entries err=%v\n", len(ents), err)
	for _, e := range ents {
		info, ierr := e.Info()
		var sz int64
		if info != nil {
			sz = info.Size()
		}
		fmt.Printf("DIRPROBE   %-12s isDir=%v type=%v info.err=%v size=%d\n", e.Name(), e.IsDir(), e.Type(), ierr, sz)
	}
	done := make(chan struct{})
	go func() {
		e2, err := os.ReadDir("/tmp/demo")
		fmt.Printf("DIRPROBE (in goroutine) %d entries err=%v\n", len(e2), err)
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		fmt.Println("DIRPROBE goroutine ReadDir TIMEOUT")
	}
	fmt.Println("POLLPROBE DONE")
	os.Exit(0)
}
