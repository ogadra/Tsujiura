package resultapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGetIdentityToken(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/computeMetadata/v1/instance/service-accounts/default/identity" || r.URL.Query().Get("audience") != tokenAudience {
			t.Errorf("requested %s", r.URL)
		}
		if _, err := w.Write([]byte("id-token")); err != nil {
			t.Error(err)
		}
	}))
	defer server.Close()
	t.Setenv("GCE_METADATA_HOST", strings.TrimPrefix(server.URL, "http://"))

	got, err := googleIDToken{}.GetIdentityToken()
	if err != nil || string(got) != "id-token" {
		t.Errorf("got %s, %v", got, err)
	}
}
