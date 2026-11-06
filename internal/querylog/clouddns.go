package querylog

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/netip"
	"time"
)

type cloudDNSEntry struct {
	Timestamp string `json:"timestamp"`
	Payload   struct {
		QueryName string `json:"queryName"`
		SourceIP  string `json:"sourceIP"`
	} `json:"jsonPayload"`
}

// ParseCloudDNS parses one Cloud DNS query log entry in the Cloud Logging LogEntry JSON format.
// It returns false without an error when the name is not a measurement name.
func ParseCloudDNS(entry []byte) (Query, bool, error) {
	var e cloudDNSEntry
	if err := json.Unmarshal(entry, &e); err != nil {
		return Query{}, false, fmt.Errorf("cloud dns query log: %w", err)
	}
	if e.Payload.QueryName == "" {
		return Query{}, false, errors.New("cloud dns query log has no query name")
	}

	token, ok := tokenFromName(e.Payload.QueryName)
	if !ok {
		return Query{}, false, nil
	}

	queriedAt, err := time.Parse(time.RFC3339, e.Timestamp)
	if err != nil {
		return Query{}, false, fmt.Errorf("cloud dns query log timestamp: %w", err)
	}
	resolverIP, err := netip.ParseAddr(e.Payload.SourceIP)
	if err != nil {
		return Query{}, false, fmt.Errorf("cloud dns query log resolver IP: %w", err)
	}

	return Query{Token: token, ResolverIP: resolverIP, Time: queriedAt}, true, nil
}
