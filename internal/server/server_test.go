package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandlerAnswersHealthzAndPassesOtherPaths(t *testing.T) {
	app := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	})
	h := Handler(app)
	tests := []struct {
		method, path string
		status       int
	}{
		{http.MethodGet, "/healthz", http.StatusOK},
		{http.MethodGet, "/", http.StatusTeapot},
		{http.MethodGet, "/api/result", http.StatusTeapot},
	}
	for _, tt := range tests {
		w := httptest.NewRecorder()
		h.ServeHTTP(w, httptest.NewRequest(tt.method, tt.path, nil))
		if w.Code != tt.status {
			t.Errorf("%s %s = %d, want %d", tt.method, tt.path, w.Code, tt.status)
		}
	}
}

func TestNewServesHandlerOnAddr(t *testing.T) {
	s := New(":8080", http.NotFoundHandler())
	if s.Addr != ":8080" || s.ReadHeaderTimeout == 0 {
		t.Errorf("addr = %q, read header timeout = %v", s.Addr, s.ReadHeaderTimeout)
	}
	w := httptest.NewRecorder()
	s.Handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if w.Code != http.StatusOK {
		t.Errorf("GET /healthz = %d, want %d", w.Code, http.StatusOK)
	}
}

func TestCheckFailsUnlessHealthzAnswersOK(t *testing.T) {
	healthy := httptest.NewServer(Handler(http.NotFoundHandler()))
	defer healthy.Close()
	if err := Check(healthy.URL + "/healthz"); err != nil {
		t.Errorf("healthy server: %v", err)
	}

	broken := httptest.NewServer(http.NotFoundHandler())
	defer broken.Close()
	if err := Check(broken.URL + "/healthz"); err == nil {
		t.Error("server without healthz: got no error")
	}

	broken.Close()
	if err := Check(broken.URL + "/healthz"); err == nil {
		t.Error("stopped server: got no error")
	}
}
