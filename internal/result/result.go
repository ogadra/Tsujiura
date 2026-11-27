package result

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/ogadra/Tsujiura/internal/querylog"
)

const (
	readTimeout = 3 * time.Second
	MaxTokens   = 10
)

type Record struct {
	ASN          int64  `json:"asn,omitempty" firestore:"asn"`
	Organization string `json:"asOrganization,omitempty" firestore:"asOrganization"`
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

func (a Aggregator) Respond(ctx context.Context, query string) (int, []byte) {
	tokens, ok := parseTokens(query)
	if !ok {
		return encode(http.StatusBadRequest, Invalid{Error: "invalid tokens"})
	}

	ctx, cancel := context.WithTimeout(ctx, readTimeout)
	defer cancel()

	found := make([]Found, len(tokens))
	dynamoDBErrs := make([]error, len(tokens))
	firestoreErrs := make([]error, len(tokens))
	var wg sync.WaitGroup
	for i, token := range tokens {
		wg.Go(func() { found[i].Route53, dynamoDBErrs[i] = a.DynamoDB.Get(ctx, token) })
		wg.Go(func() { found[i].CloudDNS, firestoreErrs[i] = a.Firestore.Get(ctx, token) })
	}
	wg.Wait()

	var unavailable []string
	for _, read := range []struct {
		database string
		err      error
	}{{"DynamoDB", errors.Join(dynamoDBErrs...)}, {"Firestore", errors.Join(firestoreErrs...)}} {
		if read.err != nil {
			slog.ErrorContext(ctx, "read result", "database", read.database, "error", read.err)
			unavailable = append(unavailable, read.database)
		}
	}
	if unavailable != nil {
		return encode(http.StatusServiceUnavailable, Unavailable{Databases: unavailable})
	}
	results := make(map[string]Found, len(tokens))
	for i, token := range tokens {
		results[token] = found[i]
	}
	return encode(http.StatusOK, results)
}

func parseTokens(query string) ([]string, bool) {
	tokens := strings.Split(query, ",")
	if len(tokens) > MaxTokens {
		return nil, false
	}
	seen := make(map[string]bool, len(tokens))
	for _, token := range tokens {
		if !querylog.IsToken(token) || seen[token] {
			return nil, false
		}
		seen[token] = true
	}
	return tokens, true
}

func (a Aggregator) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	status, body := a.Respond(r.Context(), r.URL.Query().Get("tokens"))
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if _, err := w.Write(body); err != nil {
		slog.ErrorContext(r.Context(), "write response", "error", err)
	}
}

func encode(status int, body any) (int, []byte) {
	encoded, _ := json.Marshal(body)
	return status, encoded
}

type DynamoDB struct {
	GetItem func(context.Context, *dynamodb.GetItemInput, ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
	Table   string
}

func (d DynamoDB) Get(ctx context.Context, token string) (*Record, error) {
	out, err := d.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(d.Table),
		Key:       map[string]types.AttributeValue{"token": &types.AttributeValueMemberS{Value: token}},
	})
	if err != nil {
		return nil, err
	}
	if len(out.Item) == 0 {
		return nil, nil
	}
	record := &Record{}
	if asn, ok := out.Item["asn"].(*types.AttributeValueMemberN); ok {
		if record.ASN, err = strconv.ParseInt(asn.Value, 10, 64); err != nil {
			return nil, fmt.Errorf("parse asn of %s: %w", token, err)
		}
	}
	if organization, ok := out.Item["asOrganization"].(*types.AttributeValueMemberS); ok {
		record.Organization = organization.Value
	}
	return record, nil
}
