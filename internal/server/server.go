package server

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"
)

func Handler(h http.Handler) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(http.ResponseWriter, *http.Request) {})
	mux.Handle("/", h)
	return mux
}

func New(addr string, h http.Handler) *http.Server {
	return &http.Server{Addr: addr, Handler: Handler(h), ReadHeaderTimeout: 10 * time.Second}
}

func Check(url string) error {
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s answered %d", url, resp.StatusCode)
	}
	return nil
}

func Serve(port int, newHandler func() (http.Handler, error)) {
	healthcheck := flag.Bool("healthcheck", false, "check the running server and exit")
	flag.Parse()
	if *healthcheck {
		if err := Check(fmt.Sprintf("http://127.0.0.1:%d/healthz", port)); err != nil {
			log.Fatal(err)
		}
		return
	}
	h, err := newHandler()
	if err != nil {
		log.Fatal(err)
	}
	log.Fatal(New(fmt.Sprintf(":%d", port), h).ListenAndServe())
}
