package main

import "C"

//export Nop
func Nop(x C.int) C.int { return x + 1 }

func main() {}
