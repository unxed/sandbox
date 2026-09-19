// t_http: net/http server and client over loopback (goroutines + netpoll + timers).
package main

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"time"
)

func main() {
	time.AfterFunc(90*time.Second, func() {
		fmt.Println("t_http: FAIL watchdog timeout")
		os.Exit(3)
	})
	mux := http.NewServeMux()
	mux.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "hello from Go on Hurd, path=%s", r.URL.Path)
	})
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Println("t_http: FAIL listen:", err)
		os.Exit(1)
	}
	go http.Serve(ln, mux)

	resp, err := http.Get("http://" + ln.Addr().String() + "/hello")
	if err != nil {
		fmt.Println("t_http: FAIL get:", err)
		os.Exit(1)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	fmt.Println("t_http:", resp.Status, string(body))
	fmt.Println("t_http: DONE")
}
