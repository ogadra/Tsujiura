package querylog

import (
	"fmt"
	"net/netip"

	"github.com/oschwald/maxminddb-golang/v2"
)

type ASN struct {
	Number       uint   `maxminddb:"autonomous_system_number"`
	Organization string `maxminddb:"autonomous_system_organization"`
}

type ASNDB struct {
	reader *maxminddb.Reader
}

func OpenASNDB(path string) (*ASNDB, error) {
	reader, err := maxminddb.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open ASN database: %w", err)
	}
	return &ASNDB{reader: reader}, nil
}

func (db *ASNDB) Close() error {
	return db.reader.Close()
}

// Lookup reports false when the database has no network for ip.
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
