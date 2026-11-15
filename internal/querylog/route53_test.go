package querylog

import (
	"net/netip"
	"testing"
	"time"
)

const token = "550e8400-e29b-41d4-a716-446655440000"

func TestParseRoute53(t *testing.T) {
	queriedAt := time.Date(2017, 12, 13, 8, 16, 2, 130_000_000, time.UTC)

	tests := []struct {
		name string
		line string
		ip   string
	}{
		{"IPv4", "1.0 2017-12-13T08:16:02.130Z Z1 " + token + ".tsujiura.ogadra.net A NOERROR UDP NRT57 192.0.2.1 -", "192.0.2.1"},
		{"IPv6", "1.0 2017-12-13T08:16:02.130Z Z1 " + token + ".tsujiura.ogadra.net AAAA NOERROR UDP NRT57 2001:db8::1234 2001:db8:abcd::/48", "2001:db8::1234"},
		{"trailing dot", "1.0 2017-12-13T08:16:02.130Z Z1 " + token + ".tsujiura.ogadra.net. A NOERROR UDP NRT57 192.0.2.1 -", "192.0.2.1"},
		{"mixed case", "1.0 2017-12-13T08:16:02.130Z Z1 550E8400-e29B-41D4-A716-446655440000.TsuJiura.ogadra.NET A NOERROR UDP NRT57 192.0.2.1 -", "192.0.2.1"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok, err := ParseRoute53(tt.line)
			if err != nil {
				t.Fatal(err)
			}
			if !ok {
				t.Fatal("line was discarded")
			}
			want := Query{Token: token, ResolverIP: netip.MustParseAddr(tt.ip), Time: queriedAt}
			if got != want {
				t.Errorf("got %+v, want %+v", got, want)
			}
		})
	}
}

func TestParseRoute53DiscardsOtherNames(t *testing.T) {
	names := []string{
		"tsujiura.ogadra.net",
		"www.tsujiura.ogadra.net",
		"not-a-uuid.tsujiura.ogadra.net",
		"550e8400-e29b-11d4-a716-446655440000.tsujiura.ogadra.net",
		"550e8400-e29b-41d4-1716-446655440000.tsujiura.ogadra.net",
		"a." + token + ".tsujiura.ogadra.net",
		token + ".example.com",
		token + ".tsujiura.ogadra.net.example.com",
	}
	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			_, ok, err := ParseRoute53("1.0 2017-12-13T08:16:02.130Z Z1 " + name + " A NOERROR UDP NRT57 192.0.2.1 -")
			if err != nil {
				t.Fatal(err)
			}
			if ok {
				t.Error("line was not discarded")
			}
		})
	}
}

func TestParseRoute53Errors(t *testing.T) {
	name := token + ".tsujiura.ogadra.net"
	tests := []struct {
		name string
		line string
	}{
		{"empty", ""},
		{"missing field", "1.0 2017-12-13T08:16:02.130Z Z1 " + name + " A NOERROR UDP NRT57 192.0.2.1"},
		{"unknown version", "2.0 2017-12-13T08:16:02.130Z Z1 " + name + " A NOERROR UDP NRT57 192.0.2.1 -"},
		{"bad timestamp", "1.0 yesterday Z1 " + name + " A NOERROR UDP NRT57 192.0.2.1 -"},
		{"bad resolver IP", "1.0 2017-12-13T08:16:02.130Z Z1 " + name + " A NOERROR UDP NRT57 resolver -"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, ok, err := ParseRoute53(tt.line); err == nil || ok {
				t.Errorf("got ok=%v err=%v, want an error", ok, err)
			}
		})
	}
}
