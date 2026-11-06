package querylog

import (
	"fmt"
	"net/netip"

	"github.com/oschwald/maxminddb-golang/v2"
)

// ASN is the autonomous system that announces an IP address.
type ASN struct {
	Number       uint   `maxminddb:"autonomous_system_number"`
	Organization string `maxminddb:"autonomous_system_organization"`
}

// ASNDB looks up ASNs in a GeoLite2 ASN database.
// It is safe for concurrent lookups.
type ASNDB struct {
	reader *maxminddb.Reader
}

// OpenASNDB opens the GeoLite2 ASN database at path.
func OpenASNDB(path string) (*ASNDB, error) {
	reader, err := maxminddb.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open ASN database: %w", err)
	}
	return &ASNDB{reader: reader}, nil
}

// Close releases the database.
func (db *ASNDB) Close() error {
	return db.reader.Close()
}

// Lookup returns the ASN of ip.
// It returns false without an error when the database has no network for ip.
func (db *ASNDB) Lookup(ip netip.Addr) (ASN, bool, error) {
	result := db.reader.Lookup(ip.Unmap())
	if err := result.Err(); err != nil {
		return ASN{}, false, fmt.Errorf("look up ASN of %s: %w", ip, err)
	}
	if !result.Found() {
		return ASN{}, false, nil
	}

	var asn ASN
	if err := result.Decode(&asn); err != nil {
		return ASN{}, false, fmt.Errorf("decode ASN of %s: %w", ip, err)
	}
	return asn, true, nil
}
