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
	fmt.Println("POLLPROBE DONE")
	os.Exit(0)
}
