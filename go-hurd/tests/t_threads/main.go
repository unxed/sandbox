// t_threads: every goroutine blocked in a libc call occupies an OS thread on Hurd.
// How many can the runtime create before pthread_create fails?
package main

import (
	"fmt"
	"os"
	"syscall"
	"time"
)

func main() {
	time.AfterFunc(60*time.Second, func() {
		fmt.Println("t_threads: FAIL watchdog timeout")
		os.Exit(3)
	})
	const n = 100
	fds := make([][2]int, n)
	done := make(chan int, n)
	for i := 0; i < n; i++ {
		var p [2]int
		if err := syscall.Pipe(p[:]); err != nil {
			fmt.Println("t_threads: pipe error at", i, err)
			os.Exit(1)
		}
		fds[i] = p
		go func() {
			var b [1]byte
			syscall.Read(p[0], b[:]) // blocks in libc until the write below
			done <- 1
		}()
	}
	time.Sleep(500 * time.Millisecond)
	fmt.Println("t_threads: all", n, "readers started")
	for i := 0; i < n; i++ {
		syscall.Write(fds[i][1], []byte{1})
	}
	for i := 0; i < n; i++ {
		<-done
	}
	fmt.Println("t_threads: DONE")
}
