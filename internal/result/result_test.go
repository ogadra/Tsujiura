package result

import (
	"context"
	"errors"
	"net/http"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

const token = "550e8400-e29b-41d4-a716-446655440000"

type reader struct {
	found bool
	err   error
}

func (r reader) Has(_ context.Context, got string) (bool, error) {
	if got != token {
		return false, errors.New("unexpected token " + got)
	}
	return r.found, r.err
}

type hangingReader struct{}

func (hangingReader) Has(ctx context.Context, _ string) (bool, error) {
	<-ctx.Done()
	return false, ctx.Err()
}

func TestRespond(t *testing.T) {
	failed := reader{err: errors.New("read failed")}
	tests := []struct {
		name       string
		token      string
		dynamoDB   Reader
		firestore  Reader
		wantStatus int
		wantBody   string
	}{
		{"neither", token, reader{}, reader{}, http.StatusOK, `{"route53":false,"cloudDns":false}`},
		{"route53", token, reader{found: true}, reader{}, http.StatusOK, `{"route53":true,"cloudDns":false}`},
		{"cloud dns", token, reader{}, reader{found: true}, http.StatusOK, `{"route53":false,"cloudDns":true}`},
		{"both", token, reader{found: true}, reader{found: true}, http.StatusOK, `{"route53":true,"cloudDns":true}`},
		{"dynamodb down", token, failed, reader{found: true}, http.StatusServiceUnavailable, `{"unavailable":["DynamoDB"]}`},
		{"firestore down", token, reader{found: true}, failed, http.StatusServiceUnavailable, `{"unavailable":["Firestore"]}`},
		{"both down", token, failed, failed, http.StatusServiceUnavailable, `{"unavailable":["DynamoDB","Firestore"]}`},
		{"empty token", "", reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid token"}`},
		{"path in token", "results/" + token, reader{}, reader{}, http.StatusBadRequest, `{"error":"invalid token"}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, body := Aggregator{DynamoDB: tt.dynamoDB, Firestore: tt.firestore}.Respond(context.Background(), tt.token)
			if status != tt.wantStatus {
				t.Errorf("status = %d, want %d", status, tt.wantStatus)
			}
			if string(body) != tt.wantBody {
				t.Errorf("body = %s, want %s", body, tt.wantBody)
			}
		})
	}
}

func TestRespondNamesHangingDatabase(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	status, body := Aggregator{DynamoDB: reader{}, Firestore: hangingReader{}}.Respond(ctx, token)
	if status != http.StatusServiceUnavailable {
		t.Errorf("status = %d, want %d", status, http.StatusServiceUnavailable)
	}
	if want := `{"unavailable":["Firestore"]}`; string(body) != want {
		t.Errorf("body = %s, want %s", body, want)
	}
}

func TestDynamoDBHas(t *testing.T) {
	item := map[string]types.AttributeValue{"token": &types.AttributeValueMemberS{Value: token}}
	tests := []struct {
		name string
		item map[string]types.AttributeValue
		err  error
		want bool
	}{{"found", item, nil, true}, {"missing", nil, nil, false}, {"failed read", nil, errors.New("read failed"), false}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			getItem := func(_ context.Context, in *dynamodb.GetItemInput, _ ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
				if key := in.Key["token"].(*types.AttributeValueMemberS).Value; key != token || *in.TableName != "results" {
					t.Errorf("read %s from %s", key, *in.TableName)
				}
				return &dynamodb.GetItemOutput{Item: tt.item}, tt.err
			}
			got, err := DynamoDB{GetItem: getItem, Table: "results"}.Has(context.Background(), token)
			if got != tt.want || !errors.Is(err, tt.err) {
				t.Errorf("got %v, %v, want %v, %v", got, err, tt.want, tt.err)
			}
		})
	}
}
