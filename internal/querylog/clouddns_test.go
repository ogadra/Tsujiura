package querylog

import (
	"fmt"
	"net/netip"
	"testing"
	"time"
)

const cloudDNSTimestamp = "2017-12-13T08:16:02.130456789Z"

func cloudDNSEntryJSON(timestamp, name, ip string) []byte {
	return fmt.Appendf(nil, `{
		"insertId": "1",
		"jsonPayload": {
			"authAnswer": true,
			"protocol": "UDP",
			"queryName": %q,
			"queryType": "A",
			"responseCode": 0,
			"sourceIP": %q,
			"source_type": "internet"
		},
		"resource": {"type": "dns_query"},
		"timestamp": %q
	}`, name, ip, timestamp)
}

func TestParseCloudDNS(t *testing.T) {
	queriedAt := time.Date(2017, 12, 13, 8, 16, 2, 130_456_789, time.UTC)

	tests := []struct {
		name      string
		queryName string
		ip        string
	}{
		{"IPv4", token + ".tsujiura.ogadra.net.", "192.0.2.1"},
		{"IPv6", token + ".tsujiura.ogadra.net.", "2001:db8::1234"},
		{"no trailing dot", token + ".tsujiura.ogadra.net", "192.0.2.1"},
		{"mixed case", "550E8400-e29B-41D4-A716-446655440000.TsuJiura.ogadra.NET.", "192.0.2.1"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok, err := ParseCloudDNS(cloudDNSEntryJSON(cloudDNSTimestamp, tt.queryName, tt.ip))
			if err != nil {
				t.Fatal(err)
			}
			if !ok {
				t.Fatal("entry was discarded")
			}
			want := Query{Token: token, ResolverIP: netip.MustParseAddr(tt.ip), Time: queriedAt}
			if got != want {
				t.Errorf("got %+v, want %+v", got, want)
			}
		})
	}
}

func TestParseCloudDNSDiscardsOtherNames(t *testing.T) {
	names := []string{
		".",
		"tsujiura.ogadra.net.",
		"www.tsujiura.ogadra.net.",
		"name with spaces.tsujiura.ogadra.net.",
		"a." + token + ".tsujiura.ogadra.net.",
		token + ".example.com.",
	}
	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			_, ok, err := ParseCloudDNS(cloudDNSEntryJSON("yesterday", name, "resolver"))
			if err != nil {
				t.Fatal(err)
			}
			if ok {
				t.Error("entry was not discarded")
			}
		})
	}
}

func TestParseCloudDNSErrors(t *testing.T) {
	name := token + ".tsujiura.ogadra.net."
	tests := []struct {
		name  string
		entry []byte
	}{
		{"empty", nil},
		{"not JSON", []byte("1.0 2017-12-13T08:16:02.130Z")},
		{"no payload", []byte(`{"timestamp": "` + cloudDNSTimestamp + `"}`)},
		{"bad timestamp", cloudDNSEntryJSON("yesterday", name, "192.0.2.1")},
		{"bad resolver IP", cloudDNSEntryJSON(cloudDNSTimestamp, name, "resolver")},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, ok, err := ParseCloudDNS(tt.entry); err == nil || ok {
				t.Errorf("got ok=%v err=%v, want an error", ok, err)
			}
		})
	}
}
