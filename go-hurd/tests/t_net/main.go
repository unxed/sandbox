// t_net: sockets on top of libc + the poll()-based netpoller.
package main

import (
	"fmt"
	"io"
	"net"
	"os"
	"time"
)

func check(name string, err error) {
	if err != nil {
		fmt.Println("t_net: FAIL", name+":", err)
		os.Exit(1)
	}
	fmt.Println("t_net: ok", name)
}

func main() {
	time.AfterFunc(60*time.Second, func() {
		fmt.Println("t_net: FAIL watchdog timeout")
		os.Exit(3)
	})

	// TCP echo over loopback.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	check("listen tcp", err)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() { io.Copy(c, c); c.Close() }()
		}
	}()
	c, err := net.Dial("tcp", ln.Addr().String())
	check("dial tcp", err)
	_, err = c.Write([]byte("ping over tcp"))
	check("write tcp", err)
	buf := make([]byte, 64)
	n, err := c.Read(buf)
	check("read tcp", err)
	fmt.Printf("t_net: tcp echo %q local=%v remote=%v\n", buf[:n], c.LocalAddr() != nil, c.RemoteAddr())

	// Read deadline (netpoll + timers).
	c.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	t0 := time.Now()
	_, err = c.Read(buf)
	ne, isNE := err.(net.Error)
	fmt.Println("t_net: deadline", isNE && ne.Timeout(), time.Since(t0) >= 90*time.Millisecond, err)
	c.Close()
	ln.Close()

	// UDP.
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	check("listen udp", err)
	uc, err := net.Dial("udp", pc.LocalAddr().String())
	check("dial udp", err)
	_, err = uc.Write([]byte("ping over udp"))
	check("write udp", err)
	pc.SetReadDeadline(time.Now().Add(5 * time.Second))
	n, from, err := pc.ReadFrom(buf)
	check("read udp", err)
	fmt.Printf("t_net: udp %q from-valid=%v\n", buf[:n], from != nil)
	uc.Close()
	pc.Close()

	// Unix domain socket.
	const path = "/tmp/t_net.sock"
	os.Remove(path)
	ul, err := net.Listen("unix", path)
	check("listen unix", err)
	go func() {
		c, err := ul.Accept()
		if err == nil {
			io.Copy(c, c)
			c.Close()
		}
	}()
	dc, err := net.Dial("unix", path)
	check("dial unix", err)
	dc.Write([]byte("ping over unix"))
	n, err = dc.Read(buf)
	check("read unix", err)
	fmt.Printf("t_net: unix %q\n", buf[:n])
	dc.Close()
	ul.Close()
	os.Remove(path)

	// Name resolution (pure Go resolver, /etc/hosts and resolv.conf).
	addrs, err := net.LookupHost("localhost")
	fmt.Println("t_net: lookup localhost", len(addrs) > 0, err)
	ta, err := net.ResolveTCPAddr("tcp", "127.0.0.1:80")
	fmt.Println("t_net: resolve", ta, err)
	ifs, err := net.Interfaces()
	fmt.Println("t_net: interfaces", len(ifs), err)
	fmt.Println("t_net: DONE")
}
