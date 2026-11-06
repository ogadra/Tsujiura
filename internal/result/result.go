// Package result reports which DNS provider received a measurement token.
package result

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/ogadra/Tsujiura/internal/querylog"
)

// readTimeout turns a hanging database into a 503 that names it.
const readTimeout = 3 * time.Second

// Reader reports whether a database has a record of a token.
type Reader interface {
	Has(ctx context.Context, token string) (bool, error)
}

// Aggregator reads both databases.
// DynamoDB holds the Route53 records and Firestore the Cloud DNS records.
type Aggregator struct {
	DynamoDB  Reader
	Firestore Reader
}

// Found is the 200 response body.
type Found struct {
	Route53  bool `json:"route53"`
	CloudDNS bool `json:"cloudDns"`
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
	wg.Go(func() { found.Route53, dynamoDBErr = a.DynamoDB.Has(ctx, token) })
	wg.Go(func() { found.CloudDNS, firestoreErr = a.Firestore.Has(ctx, token) })
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

// DynamoDB reads the Route53 records from a table keyed by token.
type DynamoDB struct {
	GetItem func(context.Context, *dynamodb.GetItemInput, ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
	Table   string
}

// Has implements Reader.
func (d DynamoDB) Has(ctx context.Context, token string) (bool, error) {
	out, err := d.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(d.Table),
		Key:       map[string]types.AttributeValue{"token": &types.AttributeValueMemberS{Value: token}},
	})
	if err != nil {
		return false, err
	}
	return len(out.Item) > 0, nil
}
