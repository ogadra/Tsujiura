package querylog

import (
	"fmt"
	"net/netip"
	"strings"
	"time"
)

const (
	route53Version    = "1.0"
	route53FieldCount = 10
)

// ParseRoute53 reports false for names other than measurement names.
func ParseRoute53(line string) (Query, bool, error) {
	fields := strings.Fields(line)
	if len(fields) != route53FieldCount {
		return Query{}, false, fmt.Errorf("route53 query log has %d fields, want %d: %q", len(fields), route53FieldCount, line)
	}
	if fields[0] != route53Version {
		return Query{}, false, fmt.Errorf("route53 query log has version %q, want %q: %q", fields[0], route53Version, line)
	}

	token, ok := TokenFromName(fields[3])
	if !ok {
		return Query{}, false, nil
	}

	queriedAt, err := time.Parse(time.RFC3339, fields[1])
	if err != nil {
		return Query{}, false, fmt.Errorf("route53 query log timestamp: %w", err)
	}
	resolverIP, err := netip.ParseAddr(fields[8])
	if err != nil {
		return Query{}, false, fmt.Errorf("route53 query log resolver IP: %w", err)
	}

	return Query{Token: token, ResolverIP: resolverIP, Time: queriedAt}, true, nil
}
