// Package result reports which DNS provider received a measurement token.
package result

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/ogadra/Tsujiura/internal/querylog"
)

// readTimeout turns a hanging database into a 503 that names it.
const readTimeout = 3 * time.Second

// Record is the resolver that sent the query for a token.
// The ingest functions leave the ASN out when the database has no entry for the resolver IP.
type Record struct {
	ASN          int64  `json:"asn,omitempty"`
	Organization string `json:"asOrganization,omitempty"`
}

// Reader reads the record of a token, which is nil when the database has none.
type Reader interface {
	Get(ctx context.Context, token string) (*Record, error)
}

// Aggregator reads both databases.
// DynamoDB holds the Route53 records and Firestore the Cloud DNS records.
type Aggregator struct {
	DynamoDB  Reader
	Firestore Reader
}

// Found is the 200 response body, with null for a provider that has no record.
type Found struct {
	Route53  *Record `json:"route53"`
	CloudDNS *Record `json:"cloudDns"`
}

// Unavailable is the 503 response body.
type Unavailable struct {
	Databases []string `json:"unavailable"`
}

// Invalid is the 400 response body.
type Invalid struct {
	Error string `json:"error"`
}

// Respond returns the HTTP status and JSON body of the result of token.
func (a Aggregator) Respond(ctx context.Context, token string) (int, []byte) {
	if !querylog.IsToken(token) {
		return encode(http.StatusBadRequest, Invalid{Error: "invalid token"})
	}

	ctx, cancel := context.WithTimeout(ctx, readTimeout)
	defer cancel()

	var found Found
	var dynamoDBErr, firestoreErr error
	var wg sync.WaitGroup
	wg.Go(func() { found.Route53, dynamoDBErr = a.DynamoDB.Get(ctx, token) })
	wg.Go(func() { found.CloudDNS, firestoreErr = a.Firestore.Get(ctx, token) })
	wg.Wait()

	var unavailable []string
	for _, read := range []struct {
		database string
		err      error
	}{{"DynamoDB", dynamoDBErr}, {"Firestore", firestoreErr}} {
		if read.err != nil {
			slog.ErrorContext(ctx, "read result", "database", read.database, "error", read.err)
			unavailable = append(unavailable, read.database)
		}
	}
	if unavailable != nil {
		return encode(http.StatusServiceUnavailable, Unavailable{Databases: unavailable})
	}
	return encode(http.StatusOK, found)
}

// encode ignores the error because the response bodies always marshal.
func encode(status int, body any) (int, []byte) {
	encoded, _ := json.Marshal(body)
	return status, encoded
}
