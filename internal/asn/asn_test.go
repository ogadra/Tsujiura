package asn

import (
	"net"
	"net/netip"
	"os"
	"path/filepath"
	"testing"

	"github.com/maxmind/mmdbwriter"
	"github.com/maxmind/mmdbwriter/mmdbtype"
)

// openTestDB builds a database because GeoLite2 data is not kept in the repository.
func openTestDB(t *testing.T) *DB {
	t.Helper()

	tree, err := mmdbwriter.New(mmdbwriter.Options{DatabaseType: "GeoLite2-ASN", IncludeReservedNetworks: true})
	if err != nil {
		t.Fatal(err)
	}
	networks := []struct {
		cidr         string
		number       mmdbtype.Uint32
		organization mmdbtype.String
	}{
		{"192.0.2.0/24", 64496, "IPv4 Example"},
		{"2001:db8::/32", 64497, "IPv6 Example"},
	}
	for _, n := range networks {
		_, network, err := net.ParseCIDR(n.cidr)
		if err != nil {
			t.Fatal(err)
		}
		record := mmdbtype.Map{"autonomous_system_number": n.number, "autonomous_system_organization": n.organization}
		if err := tree.Insert(network, record); err != nil {
			t.Fatal(err)
		}
	}

	path := filepath.Join(t.TempDir(), "asn.mmdb")
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if _, err := tree.WriteTo(file); err != nil {
		t.Fatal(err)
	}

	db, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestDBLookup(t *testing.T) {
	db := openTestDB(t)

	tests := []struct {
		name string
		ip   string
		want AS
	}{
		{"IPv4", "192.0.2.1", AS{Number: 64496, Organization: "IPv4 Example"}},
		{"IPv6", "2001:db8::1234", AS{Number: 64497, Organization: "IPv6 Example"}},
		{"IPv4-mapped IPv6", "::ffff:192.0.2.1", AS{Number: 64496, Organization: "IPv4 Example"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok, err := db.Lookup(netip.MustParseAddr(tt.ip))
			if err != nil {
				t.Fatal(err)
			}
			if !ok {
				t.Fatal("ASN was not found")
			}
			if got != tt.want {
				t.Errorf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}

func TestDBLookupUnknownNetwork(t *testing.T) {
	db := openTestDB(t)

	for _, ip := range []string{"198.51.100.1", "2001:db9::1"} {
		t.Run(ip, func(t *testing.T) {
			_, ok, err := db.Lookup(netip.MustParseAddr(ip))
			if err != nil {
				t.Fatal(err)
			}
			if ok {
				t.Error("ASN was found")
			}
		})
	}
}

func TestDBLookupInvalidAddr(t *testing.T) {
	db := openTestDB(t)

	if _, ok, err := db.Lookup(netip.Addr{}); err == nil || ok {
		t.Errorf("got ok=%v err=%v, want an error", ok, err)
	}
}

func TestOpenMissingFile(t *testing.T) {
	if _, err := Open(filepath.Join(t.TempDir(), "missing.mmdb")); err == nil {
		t.Error("got no error")
	}
}
