package frontend

import (
	"net/http"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"

	"github.com/ogadra/Tsujiura/internal/server"
	"github.com/ogadra/Tsujiura/web"
)

func newHandler() (http.Handler, error) {
	h, err := web.Handler("google-cloud")
	if err != nil {
		return nil, err
	}
	return server.Handler(h), nil
}

func init() {
	h, err := newHandler()
	if err != nil {
		panic(err)
	}
	functions.HTTP("Frontend", h.ServeHTTP)
}
