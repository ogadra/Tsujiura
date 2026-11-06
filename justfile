test:
    go test ./...

lint:
    go vet ./...
    test -z "$(gofmt -l .)"

# Functions take the database in their deploy artifact, so run this before deploying them.
geolite2-asn:
    curl -fsSL -u "$MAXMIND_ACCOUNT_ID:$MAXMIND_LICENSE_KEY" "https://download.maxmind.com/geoip/databases/GeoLite2-ASN/download?suffix=tar.gz" | tar -xzf - --strip-components=1 --wildcards '*/GeoLite2-ASN.mmdb'
