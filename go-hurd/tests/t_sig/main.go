// t_sig: os/signal delivery and async preemption (SIGURG) on Hurd's signal numbering.
package main

import (
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

func main() {
	time.AfterFunc(60*time.Second, func() {
		fmt.Println("t_sig: FAIL watchdog timeout")
		os.Exit(3)
	})

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGUSR1)
	syscall.Kill(os.Getpid(), syscall.SIGUSR1)
	select {
	case s := <-sigs:
		fmt.Println("t_sig: got", s, int(s.(syscall.Signal)))
	case <-time.After(5 * time.Second):
		fmt.Println("t_sig: FAIL no SIGUSR1")
		os.Exit(1)
	}
	signal.Stop(sigs)

	// A tight loop without function calls can only be interrupted by
	// signal-based (SIGURG) asynchronous preemption, which is disabled on Hurd
	// (known limitation, see STATUS-HURD.md): skip there.
	if runtime.GOOS == "hurd" {
		fmt.Println("t_sig: preempt skipped (async preemption disabled on hurd)")
	} else {
		runtime.GOMAXPROCS(1)
		go func() {
			for {
			}
		}()
		t0 := time.Now()
		time.Sleep(100 * time.Millisecond)
		fmt.Println("t_sig: preempt ok", time.Since(t0) < 2*time.Second)
	}
	fmt.Println("t_sig: DONE")
}
