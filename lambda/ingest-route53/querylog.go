package main

import (
	"fmt"
	"net/netip"
	"strings"
	"time"

	"github.com/ogadra/Tsujiura/internal/querylog"
)

const (
	route53Version    = "1.0"
	route53FieldCount = 10
)

// parseQueryLog reports false for names other than measurement names.
func parseQueryLog(line string) (querylog.Query, bool, error) {
	fields := strings.Fields(line)
	if len(fields) != route53FieldCount {
		return querylog.Query{}, false, fmt.Errorf("route53 query log has %d fields, want %d: %q", len(fields), route53FieldCount, line)
	}
	if fields[0] != route53Version {
		return querylog.Query{}, false, fmt.Errorf("route53 query log has version %q, want %q: %q", fields[0], route53Version, line)
	}

	token, ok := querylog.TokenFromName(fields[3])
	if !ok {
		return querylog.Query{}, false, nil
	}

	queriedAt, err := time.Parse(time.RFC3339, fields[1])
	if err != nil {
		return querylog.Query{}, false, fmt.Errorf("route53 query log timestamp: %w", err)
	}
	resolverIP, err := netip.ParseAddr(fields[8])
	if err != nil {
		return querylog.Query{}, false, fmt.Errorf("route53 query log resolver IP: %w", err)
	}

	return querylog.Query{Token: token, ResolverIP: resolverIP, Time: queriedAt}, true, nil
}
