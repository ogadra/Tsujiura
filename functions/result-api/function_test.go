package resultapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

const token = "550e8400-e29b-41d4-a716-446655440000"

func TestHandle(t *testing.T) {
	a := &api{respond: func(_ context.Context, got string) (int, []byte) {
		if got != token {
			t.Errorf("token = %q, want %q", got, token)
		}
		return http.StatusServiceUnavailable, []byte(`{"unavailable":["DynamoDB"]}`)
	}}

	w := httptest.NewRecorder()
	a.handle(w, httptest.NewRequest(http.MethodGet, "/api/result?token="+token, nil))

	if w.Code != http.StatusServiceUnavailable || w.Header().Get("Content-Type") != "application/json" || w.Body.String() != `{"unavailable":["DynamoDB"]}` {
		t.Errorf("got %d %v %s", w.Code, w.Header(), w.Body)
	}
}
