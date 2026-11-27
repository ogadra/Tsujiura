package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHandlerServesAWSProviderImage(t *testing.T) {
	h, err := newHandler()
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile("../../web/provider/aws.svg")
	if err != nil {
		t.Fatal(err)
	}

	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/provider.svg", nil))

	if w.Code != http.StatusOK || w.Body.String() != string(want) {
		t.Errorf("got %d %s", w.Code, w.Body)
	}
}
