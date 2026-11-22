package result

import (
	"context"
	"errors"
	"net/http"
	"testing"
	"time"
)

const token = "550e8400-e29b-41d4-a716-446655440000"

type reader struct {
	record *Record
	err    error
}

func (r reader) Get(_ context.Context, got string) (*Record, error) {
	if got != token {
		return nil, errors.New("unexpected token " + got)
	}
	return r.record, r.err
}

type hangingReader struct{}

func (hangingReader) Get(ctx context.Context, _ string) (*Record, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}

func TestRespond(t *testing.T) {
	failed := reader{err: errors.New("read failed")}
	kddi := reader{record: &Record{ASN: 2516, Organization: "KDDI CORPORATION"}}
	google := reader{record: &Record{ASN: 15169, Organization: "GOOGLE"}}
	unknown := reader{record: &Record{}}
	tests := []struct {
		name       string
		token      string
		dynamoDB   Reader
		firestore  Reader
		wantStatus int
		wantBody   string
	}{
		{"neither", token, reader{}, reader{}, http.StatusOK, `{"route53":null,"cloudDns":null}`},
		{"route53", token, kddi, reader{}, http.StatusOK, `{"route53":{"asn":2516,"asOrganization":"KDDI CORPORATION"},"cloudDns":null}`},
		{"cloud dns", token, reader{}, google, http.StatusOK, `{"route53":null,"cloudDns":{"asn":15169,"asOrganization":"GOOGLE"}}`},
		{"both", token, kddi, google, http.StatusOK, `{"route53":{"asn":2516,"asOrganization":"KDDI CORPORATION"},"cloudDns":{"asn":15169,"asOrganization":"GOOGLE"}}`},
		{"unknown asn", token, unknown, reader{}, http.StatusOK, `{"route53":{},"cloudDns":null}`},
		{"dynamodb down", token, failed, google, http.StatusServiceUnavailable, `{"unavailable":["DynamoDB"]}`},
		{"firestore down", token, kddi, failed, http.StatusServiceUnavailable, `{"unavailable":["Firestore"]}`},
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
