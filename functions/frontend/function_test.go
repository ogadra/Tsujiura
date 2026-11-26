package frontend

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandle(t *testing.T) {
	tests := []struct {
		path, contentType, body string
		status                  int
	}{
		{"/", "text/html; charset=utf-8", "<title>Tsujiura</title>", http.StatusOK},
		{"/provider.svg", "image/svg+xml", `width="2"`, http.StatusOK},
		{"/missing", "", "", http.StatusNotFound},
	}
	for _, tt := range tests {
		w := httptest.NewRecorder()
		handle(w, httptest.NewRequest(http.MethodGet, tt.path, nil))
		if w.Code != tt.status || w.Header().Get("Content-Type") != tt.contentType || !strings.Contains(w.Body.String(), tt.body) {
			t.Errorf("%s: got %d %v %s", tt.path, w.Code, w.Header(), w.Body)
		}
	}
}
