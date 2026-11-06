// Package querylog extracts measurement tokens from DNS query logs.
package querylog

import (
	"net/netip"
	"regexp"
	"strings"
	"time"
)

var tokenName = regexp.MustCompile(`^([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.tsujiura\.ogadra\.net$`)

// Query is one DNS query for a measurement token.
type Query struct {
	Token      string
	ResolverIP netip.Addr
	Time       time.Time
}

// tokenFromName returns the token of a <token>.tsujiura.ogadra.net name.
// Names are lowered first because resolvers may randomize their case.
func tokenFromName(name string) (string, bool) {
	m := tokenName.FindStringSubmatch(strings.ToLower(strings.TrimSuffix(name, ".")))
	if m == nil {
		return "", false
	}
	return m[1], true
}
