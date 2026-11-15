package asn

import (
	"fmt"
	"net/netip"

	"github.com/oschwald/maxminddb-golang/v2"
)

type AS struct {
	Number       uint   `maxminddb:"autonomous_system_number"`
	Organization string `maxminddb:"autonomous_system_organization"`
}

type DB struct {
	reader *maxminddb.Reader
}

// The ingest functions read the database from object storage, so it is opened from bytes instead of a file.
func New(data []byte) (*DB, error) {
	reader, err := maxminddb.OpenBytes(data)
	if err != nil {
		return nil, fmt.Errorf("open ASN database: %w", err)
	}
	return &DB{reader: reader}, nil
}

// Lookup reports false when the database has no network for ip.
func (db *DB) Lookup(ip netip.Addr) (AS, bool, error) {
	result := db.reader.Lookup(ip.Unmap())
	if err := result.Err(); err != nil {
		return AS{}, false, fmt.Errorf("look up ASN of %s: %w", ip, err)
	}
	if !result.Found() {
		return AS{}, false, nil
	}

	var asn AS
	if err := result.Decode(&asn); err != nil {
		return AS{}, false, fmt.Errorf("decode ASN of %s: %w", ip, err)
	}
	return asn, true, nil
}
