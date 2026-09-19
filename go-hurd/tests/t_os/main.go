// t_os: the smallest program that imports "os" (milestone step 1).
package main

import "os"

func main() {
	os.Stdout.WriteString("t_os: hello via os.Stdout\n")
}
