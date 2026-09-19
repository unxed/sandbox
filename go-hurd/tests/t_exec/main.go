// t_exec: fork+exec from a multithreaded Go process (glibc Hurd fork is the risk).
package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"time"
)

func main() {
	time.AfterFunc(90*time.Second, func() {
		fmt.Println("t_exec: FAIL watchdog timeout")
		os.Exit(3)
	})

	p, err := exec.LookPath("sh")
	fmt.Println("t_exec: lookpath sh", p, err)

	out, err := exec.Command("/bin/echo", "hello from child").Output()
	fmt.Printf("t_exec: echo %q %v\n", out, err)

	err = exec.Command("/bin/sh", "-c", "exit 3").Run()
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		fmt.Println("t_exec: exit status", ee.ExitCode())
	} else {
		fmt.Println("t_exec: FAIL expected ExitError, got", err)
	}

	cmd := exec.Command("/bin/cat")
	in, _ := cmd.StdinPipe()
	outp, _ := cmd.StdoutPipe()
	if err := cmd.Start(); err != nil {
		fmt.Println("t_exec: FAIL start cat:", err)
		os.Exit(1)
	}
	io.WriteString(in, "through cat\n")
	in.Close()
	b, _ := io.ReadAll(outp)
	err = cmd.Wait()
	fmt.Printf("t_exec: cat %q %v\n", b, err)

	_, err = exec.Command("/nonexistent/prog").Output()
	fmt.Println("t_exec: missing binary:", err)
	fmt.Println("t_exec: DONE")
}
