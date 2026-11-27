package frontend

import (
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"

	"github.com/ogadra/Tsujiura/web"
)

func init() {
	h, err := web.Handler("google-cloud")
	if err != nil {
		panic(err)
	}
	functions.HTTP("Frontend", h.ServeHTTP)
}
