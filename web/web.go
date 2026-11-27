package web

import (
	"embed"
	"io/fs"
	"log/slog"
	"net/http"
)

//go:embed index.html provider/*.svg
var files embed.FS

type asset struct {
	body        []byte
	contentType string
}

type site map[string]asset

func Handler(provider string) (http.Handler, error) {
	index, err := fs.ReadFile(files, "index.html")
	if err != nil {
		return nil, err
	}
	svg, err := fs.ReadFile(files, "provider/"+provider+".svg")
	if err != nil {
		return nil, err
	}
	return site{
		"/":             {index, "text/html; charset=utf-8"},
		"/provider.svg": {svg, "image/svg+xml"},
		"/healthz":      {nil, "text/plain; charset=utf-8"},
	}, nil
}

func (s site) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	a, ok := s[r.URL.Path]
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", a.contentType)
	if _, err := w.Write(a.body); err != nil {
		slog.ErrorContext(r.Context(), "write response", "error", err)
	}
}
