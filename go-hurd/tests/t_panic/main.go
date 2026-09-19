// t_panic: runtime panics that originate from hardware faults. The runtime turns
// SIGSEGV/SIGFPE into a call to sigpanic by rewriting the interrupted context, so
// this only works if the OS honors register changes made by the signal handler.
package main

import (
	"fmt"
	"os"
	"time"
	"unsafe"
)

func try(name string, f func()) {
	defer func() {
		fmt.Println("t_panic:", name, "->", recover())
	}()
	f()
}

func main() {
	time.AfterFunc(30*time.Second, func() {
		fmt.Println("t_panic: FAIL watchdog timeout")
		os.Exit(3)
	})
	var p *int
	try("nil deref", func() { _ = *p })
	zero := 0
	try("divide by zero", func() { fmt.Println(1 / zero) })
	try("wild address", func() { _ = *(*int)(unsafe.Pointer(uintptr(8))) })
	try("index", func() { s := []int{}; _ = s[zero+3] })
	try("explicit", func() { panic("boom") })
	fmt.Println("t_panic: DONE")
}
