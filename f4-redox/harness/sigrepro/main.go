// sigrepro: does signal.Notify(SIGWINCH) hang after spawning a child process (as f4 does
// when it starts its shell)? Prints OK/step markers; a hang shows up as a missing OK.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	mode := "spawn"
	if len(os.Args) > 1 {
		mode = os.Args[1]
	}
	var cmd *exec.Cmd
	if mode == "spawn" {
		cmd = exec.Command("/usr/bin/sh", "-c", "sleep 20")
		if err := cmd.Start(); err != nil {
			fmt.Println("SIGREPRO start:", err)
			os.Exit(1)
		}
		fmt.Println("SIGREPRO child started pid", cmd.Process.Pid)
		time.Sleep(200 * time.Millisecond)
	}
	fmt.Println("SIGREPRO before Notify")
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGWINCH)
	fmt.Println("SIGREPRO after Notify")
	syscall.Kill(os.Getpid(), syscall.SIGWINCH)
	select {
	case s := <-ch:
		fmt.Println("SIGREPRO got", s)
	case <-time.After(2 * time.Second):
		fmt.Println("SIGREPRO no signal within 2s")
	}
	if cmd != nil {
		cmd.Process.Kill()
	}
	fmt.Println("SIGREPRO OK", mode)
	os.Exit(0)
}
