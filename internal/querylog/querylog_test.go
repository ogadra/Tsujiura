package querylog

import "testing"

func TestTokenFromNameAcceptsAnyDomain(t *testing.T) {
	const token = "550e8400-e29b-41d4-a716-446655440000"

	got, ok := TokenFromName(token + ".example.com.")
	if !ok {
		t.Fatal("name was discarded")
	}
	if got != token {
		t.Errorf("got %q, want %q", got, token)
	}
}
