// t_rt: scheduler, timers, GC and threads on top of the libc-based runtime.
package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

func main() {
	var wg sync.WaitGroup
	res := make([]int, 8)
	for i := range res {
		wg.Add(1)
		go func() {
			defer wg.Done()
			time.Sleep(10 * time.Millisecond)
			res[i] = i * i
		}()
	}
	wg.Wait()
	fmt.Println("t_rt: goroutines", res)

	t0 := time.Now()
	time.Sleep(50 * time.Millisecond)
	fmt.Println("t_rt: sleep ok", time.Since(t0) >= 50*time.Millisecond)

	var junk [][]byte
	for i := 0; i < 200; i++ {
		junk = append(junk, make([]byte, 64<<10))
		if i%50 == 0 {
			runtime.GC()
		}
	}
	fmt.Println("t_rt: gc ok", len(junk))

	tk := time.NewTicker(5 * time.Millisecond)
	for i := 0; i < 3; i++ {
		<-tk.C
	}
	tk.Stop()
	fmt.Println("t_rt: ticker ok")

	ch := make(chan int)
	go func() {
		select {
		case ch <- 1:
		case <-time.After(time.Second):
		}
	}()
	fmt.Println("t_rt: chan", <-ch)
	fmt.Println("t_rt:", runtime.GOOS, runtime.GOARCH, runtime.NumCPU() > 0, runtime.NumGoroutine() > 0)
}
