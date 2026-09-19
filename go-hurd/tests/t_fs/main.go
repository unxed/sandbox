// t_fs: files, directories, errors, environment, working directory.
package main

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"sort"
)

func main() {
	fi, err := os.Stat("/etc/passwd")
	if err == nil {
		fmt.Println("t_fs: stat", fi.Name(), fi.Size() > 0, fi.Mode().IsRegular(), fi.ModTime().Year() > 2000)
	} else {
		fmt.Println("t_fs: stat error:", err)
	}

	b, err := os.ReadFile("/etc/hostname")
	fmt.Printf("t_fs: readfile %q %v\n", b, err)

	des, err := os.ReadDir("/etc")
	names := make([]string, 0, len(des))
	for _, d := range des {
		names = append(names, d.Name())
	}
	sort.Strings(names)
	fmt.Println("t_fs: readdir", len(names) > 10, err, names[:min(3, len(names))])

	const tmp = "/tmp/t_fs.txt"
	err = os.WriteFile(tmp, []byte("hurd\n"), 0o644)
	fmt.Println("t_fs: write", err)
	b, err = os.ReadFile(tmp)
	fmt.Printf("t_fs: reread %q %v\n", b, err)
	fmt.Println("t_fs: remove", os.Remove(tmp))

	_, err = os.Stat("/nonexistent")
	fmt.Println("t_fs: enoent:", err, os.IsNotExist(err), errors.Is(err, fs.ErrNotExist))
	_, err = os.Open("/root/.x/y/z")
	fmt.Println("t_fs: open err:", err)

	wd, err := os.Getwd()
	fmt.Println("t_fs: getwd", wd, err)
	h, err := os.Hostname()
	fmt.Println("t_fs: hostname", h != "", err)
	fmt.Println("t_fs: args", len(os.Args), "home set:", os.Getenv("HOME") != "")
	fmt.Println("t_fs: pid", os.Getpid() > 0, "uid", os.Getuid())

	r, w, err := os.Pipe()
	if err == nil {
		go func() { w.WriteString("through a pipe\n"); w.Close() }()
		buf := make([]byte, 64)
		n, _ := r.Read(buf)
		fmt.Printf("t_fs: pipe %q\n", buf[:n])
	} else {
		fmt.Println("t_fs: pipe error:", err)
	}
}
