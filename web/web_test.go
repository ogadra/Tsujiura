package web

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	tests := []struct {
		provider, path, contentType, body string
		status                            int
	}{
		{"aws", "/", "text/html; charset=utf-8", `<p class="served-by aws">このページを返したクラウド <strong>AWS</strong></p>`, http.StatusOK},
		{"aws", "/provider.svg", "image/svg+xml", `width="1"`, http.StatusOK},
		{"aws", "/missing", "", "", http.StatusNotFound},
		{"google-cloud", "/", "text/html; charset=utf-8", `<p class="served-by google-cloud">このページを返したクラウド <strong>Google Cloud</strong></p>`, http.StatusOK},
		{"google-cloud", "/provider.svg", "image/svg+xml", `width="2"`, http.StatusOK},
		{"google-cloud", "/missing", "", "", http.StatusNotFound},
	}
	for _, tt := range tests {
		h, err := Handler(tt.provider)
		if err != nil {
			t.Fatal(err)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, tt.path, nil))
		if w.Code != tt.status || w.Header().Get("Content-Type") != tt.contentType || !strings.Contains(w.Body.String(), tt.body) {
			t.Errorf("%s %s: got %d %v %s", tt.provider, tt.path, w.Code, w.Header(), w.Body)
		}
	}
}

func TestHandlerUnknownProvider(t *testing.T) {
	if _, err := Handler("missing"); err == nil {
		t.Error("got nil error")
	}
}
