package result

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

const (
	token  = "550e8400-e29b-41d4-a716-446655440000"
	token2 = "6ba7b810-9dad-41d1-80b4-00c04fd430c8" // gitleaks:allow
)

type reader struct {
	records map[string]*Record
	err     error
}

func (r reader) Get(_ context.Context, got string) (*Record, error) {
	if got != token && got != token2 {
		return nil, errors.New("unexpected token " + got)
	}
	return r.records[got], r.err
}

type hangingReader struct{}

func (hangingReader) Get(ctx context.Context, _ string) (*Record, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}

type failingReader struct{ token string }

func (f failingReader) Get(_ context.Context, got string) (*Record, error) {
	if got == f.token {
		return nil, errors.New("read failed")
	}
	return nil, nil
}

func tokens(n int) string {
	list := make([]string, n)
	for i := range list {
		list[i] = fmt.Sprintf("550e8400-e29b-41d4-a716-%012d", i)
	}
	return strings.Join(list, ",")
}

func TestRespond(t *testing.T) {
	failed := reader{err: errors.New("read failed")}
	kddi := &Record{ASN: 2516, Organization: "KDDI CORPORATION"}
	google := &Record{ASN: 15169, Organization: "GOOGLE"}
	tests := []struct {
		name       string
		query      string
		dynamoDB   Reader
		firestore  Reader
		wantStatus int
		wantBody   string
	}{
		{"neither", token, reader{}, reader{}, http.StatusOK, `{"` + token + `":{"route53":null,"cloudDns":null}}`},
		{"route53", token, reader{records: map[string]*Record{token: kddi}}, reader{}, http.StatusOK, `{"` + token + `":{"route53":{"asn":2516,"asOrganization":"KDDI CORPORATION"},"cloudDns":null}}`},
		{"cloud dns", token, reader{}, reader{records: map[string]*Record{token: google}}, http.StatusOK, `{"` + token + `":{"route53":null,"cloudDns":{"asn":15169,"asOrganization":"GOOGLE"}}}`},
		{"unknown asn", token, reader{records: map[string]*Record{token: {}}}, reader{}, http.StatusOK, `{"` + token + `":{"route53":{},"cloudDns":null}}`},
		{
			"each token", token + "," + token2,
			reader{records: map[string]*Record{token: kddi}}, reader{records: map[string]*Record{token2: google}},
			http.StatusOK,
			`{"` + token + `":{"route53":{"asn":2516,"asOrganization":"KDDI CORPORATION"},"cloudDns":null},"` + token2 + `":{"route53":null,"cloudDns":{"asn":15169,"asOrganization":"GOOGLE"}}}`,
		},
		{"dynamodb down", token, failed, reader{}, http.StatusServiceUnavailable, `{"unavailable":["DynamoDB"]}`},
		{"firestore down", token, reader{}, failed, http.StatusServiceUnavailable, `{"unavailable":["Firestore"]}`},
		{"both down", token, failed, failed, http.StatusServiceUnavailable, `{"unavailable":["DynamoDB","Firestore"]}`},
		{"one token unreadable", token + "," + token2, reader{}, failingReader{token: token2}, http.StatusServiceUnavailable, `{"unavailable":["Firestore"]}`},
		{"empty", "", reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid tokens"}`},
		{"path in token", "results/" + token, reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid tokens"}`},
		{"one invalid among valid", token + ",invalid", reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid tokens"}`},
		{"trailing comma", token + ",", reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid tokens"}`},
		{"duplicate", token + "," + token, reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid tokens"}`},
		{"over limit", tokens(MaxTokens + 1), reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid tokens"}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, body := Aggregator{DynamoDB: tt.dynamoDB, Firestore: tt.firestore}.Respond(context.Background(), tt.query)
			if status != tt.wantStatus {
				t.Errorf("status = %d, want %d", status, tt.wantStatus)
			}
			if string(body) != tt.wantBody {
				t.Errorf("body = %s, want %s", body, tt.wantBody)
			}
		})
	}
}

func TestRespondAnswersUpToMaxTokens(t *testing.T) {
	status, body := Aggregator{DynamoDB: emptyReader{}, Firestore: emptyReader{}}.Respond(context.Background(), tokens(MaxTokens))
	if status != http.StatusOK {
		t.Fatalf("status = %d, body = %s", status, body)
	}
	var results map[string]Found
	if err := json.Unmarshal(body, &results); err != nil {
		t.Fatal(err)
	}
	if len(results) != MaxTokens {
		t.Errorf("got %d results, want %d", len(results), MaxTokens)
	}
}

type emptyReader struct{}

func (emptyReader) Get(context.Context, string) (*Record, error) { return nil, nil }

func TestRespondNamesHangingDatabase(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	status, body := Aggregator{DynamoDB: reader{}, Firestore: hangingReader{}}.Respond(ctx, token+","+token2)
	if status != http.StatusServiceUnavailable {
		t.Errorf("status = %d, want %d", status, http.StatusServiceUnavailable)
	}
	if want := `{"unavailable":["Firestore"]}`; string(body) != want {
		t.Errorf("body = %s, want %s", body, want)
	}
}

func TestServeHTTPAnswersWithTokensFromQuery(t *testing.T) {
	w := httptest.NewRecorder()
	Aggregator{DynamoDB: reader{records: map[string]*Record{token2: {}}}, Firestore: reader{}}.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/api/result?tokens="+token+","+token2, nil))

	want := `{"` + token + `":{"route53":null,"cloudDns":null},"` + token2 + `":{"route53":{},"cloudDns":null}}`
	if w.Code != http.StatusOK || w.Header().Get("Content-Type") != "application/json" || w.Body.String() != want {
		t.Errorf("got %d %v %s", w.Code, w.Header(), w.Body)
	}
}

func TestDynamoDBGet(t *testing.T) {
	tokenOnly := map[string]types.AttributeValue{"token": &types.AttributeValueMemberS{Value: token}}
	withASN := map[string]types.AttributeValue{
		"token":          &types.AttributeValueMemberS{Value: token},
		"asn":            &types.AttributeValueMemberN{Value: "2516"},
		"asOrganization": &types.AttributeValueMemberS{Value: "KDDI CORPORATION"},
	}
	brokenASN := map[string]types.AttributeValue{
		"token": &types.AttributeValueMemberS{Value: token},
		"asn":   &types.AttributeValueMemberN{Value: "AS2516"},
	}
	readFailed := errors.New("read failed")
	tests := []struct {
		name    string
		item    map[string]types.AttributeValue
		readErr error
		want    *Record
		wantErr bool
	}{
		{"with asn", withASN, nil, &Record{ASN: 2516, Organization: "KDDI CORPORATION"}, false},
		{"without asn", tokenOnly, nil, &Record{}, false},
		{"missing", nil, nil, nil, false},
		{"failed read", nil, readFailed, nil, true},
		{"broken asn", brokenASN, nil, nil, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			getItem := func(_ context.Context, in *dynamodb.GetItemInput, _ ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
				if key := in.Key["token"].(*types.AttributeValueMemberS).Value; key != token || *in.TableName != "results" {
					t.Errorf("read %s from %s", key, *in.TableName)
				}
				return &dynamodb.GetItemOutput{Item: tt.item}, tt.readErr
			}
			got, err := DynamoDB{GetItem: getItem, Table: "results"}.Get(context.Background(), token)
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v, want error %v", err, tt.wantErr)
			}
			if tt.readErr != nil && !errors.Is(err, tt.readErr) {
				t.Errorf("err = %v, want %v", err, tt.readErr)
			}
			if (got == nil) != (tt.want == nil) || (got != nil && *got != *tt.want) {
				t.Errorf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}
