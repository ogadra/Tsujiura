package ingestclouddns

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/netip"
	"time"

	"github.com/ogadra/Tsujiura/internal/querylog"
)

type cloudDNSEntry struct {
	Timestamp string `json:"timestamp"`
	Payload   struct {
		QueryName string `json:"queryName"`
		SourceIP  string `json:"sourceIP"`
	} `json:"jsonPayload"`
}

// parseQueryLog reports false for names other than measurement names.
func parseQueryLog(entry []byte) (querylog.Query, bool, error) {
	var e cloudDNSEntry
	if err := json.Unmarshal(entry, &e); err != nil {
		return querylog.Query{}, false, fmt.Errorf("cloud dns query log: %w", err)
	}
	if e.Payload.QueryName == "" {
		return querylog.Query{}, false, errors.New("cloud dns query log has no query name")
	}

	token, ok := querylog.TokenFromName(e.Payload.QueryName)
	if !ok {
		return querylog.Query{}, false, nil
	}

	queriedAt, err := time.Parse(time.RFC3339, e.Timestamp)
	if err != nil {
		return querylog.Query{}, false, fmt.Errorf("cloud dns query log timestamp: %w", err)
	}
	resolverIP, err := netip.ParseAddr(e.Payload.SourceIP)
	if err != nil {
		return querylog.Query{}, false, fmt.Errorf("cloud dns query log resolver IP: %w", err)
	}

	return querylog.Query{Token: token, ResolverIP: resolverIP, Time: queriedAt}, true, nil
}
