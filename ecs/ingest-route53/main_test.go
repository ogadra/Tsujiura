package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"
)

const requestID = "ed4acda5-034f-9f42-bba1-f29aea6d7d8f"

var processedAt = time.UnixMilli(1578090903599)

func post(t *testing.T, h http.Handler, method, body string) (int, http.Header, firehoseResponse) {
	t.Helper()
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(method, "/", strings.NewReader(body)))
	var response firehoseResponse
	if w.Header().Get("Content-Type") == "application/json" {
		if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
			t.Fatal(err)
		}
	}
	return w.Code, w.Header(), response
}

func TestReceiverIngestsEveryRecord(t *testing.T) {
	var got []string
	rc := receiver{
		ingest: func(_ context.Context, compressed []byte) error { got = append(got, string(compressed)); return nil },
		now:    func() time.Time { return processedAt },
	}

	status, header, response := post(t, rc, http.MethodPost, `{"requestId":"`+requestID+`","timestamp":1578090901599,"records":[{"data":"aGVsbG8="},{"data":"d29ybGQ="}]}`)

	if want := []string{"hello", "world"}; !reflect.DeepEqual(got, want) {
		t.Errorf("ingested %q, want %q", got, want)
	}
	want := firehoseResponse{RequestID: requestID, Timestamp: processedAt.UnixMilli()}
	if status != http.StatusOK || header.Get("Content-Length") == "" || response != want {
		t.Errorf("got %d %v %+v, want 200 %+v", status, header, response, want)
	}
}

func TestReceiverReportsFailures(t *testing.T) {
	failing := receiver{
		ingest: func(context.Context, []byte) error { return errors.New("put failed") },
		now:    func() time.Time { return processedAt },
	}
	tests := []struct {
		name   string
		body   string
		status int
		want   firehoseResponse
	}{
		{"ingest fails", `{"requestId":"` + requestID + `","records":[{"data":"aGVsbG8="}]}`, http.StatusInternalServerError, firehoseResponse{RequestID: requestID, Timestamp: processedAt.UnixMilli(), ErrorMessage: "put failed"}},
		{"data is not base64", `{"requestId":"` + requestID + `","records":[{"data":"!"}]}`, http.StatusBadRequest, firehoseResponse{RequestID: requestID, Timestamp: processedAt.UnixMilli()}},
		{"body is not json", `records`, http.StatusBadRequest, firehoseResponse{Timestamp: processedAt.UnixMilli()}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, _, response := post(t, failing, http.MethodPost, tt.body)
			if status != tt.status || response.RequestID != tt.want.RequestID || response.Timestamp != tt.want.Timestamp || response.ErrorMessage == "" {
				t.Errorf("got %d %+v, want %d %+v", status, response, tt.status, tt.want)
			}
		})
	}
}

func TestReceiverAcceptsOnlyPost(t *testing.T) {
	rc := receiver{
		ingest: func(context.Context, []byte) error { t.Error("ingested a GET request"); return nil },
		now:    time.Now,
	}
	status, header, _ := post(t, rc, http.MethodGet, "")
	if status != http.StatusMethodNotAllowed || header.Get("Allow") != http.MethodPost {
		t.Errorf("got %d %v", status, header)
	}
}
