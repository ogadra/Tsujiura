package frontend

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHandlerAnswersHealthzAndServesGoogleCloudProviderImage(t *testing.T) {
	h, err := newHandler()
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile("../../web/provider/google-cloud.svg")
	if err != nil {
		t.Fatal(err)
	}

	health := httptest.NewRecorder()
	h.ServeHTTP(health, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if health.Code != http.StatusOK {
		t.Errorf("GET /healthz = %d, want %d", health.Code, http.StatusOK)
	}

	image := httptest.NewRecorder()
	h.ServeHTTP(image, httptest.NewRequest(http.MethodGet, "/provider.svg", nil))
	if image.Code != http.StatusOK || image.Body.String() != string(want) {
		t.Errorf("GET /provider.svg = %d %s", image.Code, image.Body)
	}
}
