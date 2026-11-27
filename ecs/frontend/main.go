package main

import (
	"net/http"

	"github.com/ogadra/Tsujiura/internal/server"
	"github.com/ogadra/Tsujiura/web"
)

func newHandler() (http.Handler, error) {
	return web.Handler("aws")
}

func main() {
	server.Serve(8080, newHandler)
}
