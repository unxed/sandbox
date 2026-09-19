// t_fmt: the phase-2 milestone: fmt.Println on real GNU Hurd.
package main

import "fmt"

func main() {
	fmt.Println("t_fmt: hello from fmt.Println", 42, 3.14, true)
	fmt.Printf("t_fmt: printf %s %d %x %v\n", "str", -7, 255, []string{"a", "b"})
}
