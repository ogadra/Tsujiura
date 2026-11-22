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

const readTimeout = 3 * time.Second

type Record struct {
	ASN          int64  `json:"asn,omitempty"`
	Organization string `json:"asOrganization,omitempty"`
}

type Reader interface {
	Get(ctx context.Context, token string) (*Record, error)
}

type Aggregator struct {
	DynamoDB  Reader
	Firestore Reader
}

type Found struct {
	Route53  *Record `json:"route53"`
	CloudDNS *Record `json:"cloudDns"`
}

type Unavailable struct {
	Databases []string `json:"unavailable"`
}

type Invalid struct {
	Error string `json:"error"`
}

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

func encode(status int, body any) (int, []byte) {
	encoded, _ := json.Marshal(body)
	return status, encoded
}
