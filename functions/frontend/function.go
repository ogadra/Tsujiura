package frontend

import (
	"log/slog"
	"net/http"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"

	"github.com/ogadra/Tsujiura/web"
)

var assets = map[string]struct{ file, contentType string }{
	"/":             {"index.html", "text/html; charset=utf-8"},
	"/provider.svg": {"provider/google-cloud.svg", "image/svg+xml"},
}

func init() {
	functions.HTTP("Frontend", handle)
}

func handle(w http.ResponseWriter, r *http.Request) {
	asset, ok := assets[r.URL.Path]
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	body, err := web.GoogleCloud.ReadFile(asset.file)
	if err != nil {
		slog.ErrorContext(r.Context(), "read asset", "file", asset.file, "error", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", asset.contentType)
	if _, err := w.Write(body); err != nil {
		slog.ErrorContext(r.Context(), "write response", "error", err)
	}
}
