package ingestclouddns

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/netip"
	"testing"
	"time"

	"github.com/cloudevents/sdk-go/v2/event"

	"github.com/ogadra/Tsujiura/internal/querylog"
)

const token = "550e8400-e29b-41d4-a716-446655440000"

func TestIngest(t *testing.T) {
	queriedAt := time.Date(2017, 12, 13, 8, 16, 2, 0, time.UTC)
	entry := func(name string) string {
		return fmt.Sprintf(`{"jsonPayload":{"queryName":%q,"sourceIP":"192.0.2.1"},"timestamp":%q}`, name, queriedAt.Format(time.RFC3339))
	}
	message := func(entry string) string {
		body, _ := json.Marshal(map[string]any{"message": map[string][]byte{"data": []byte(entry)}})
		return string(body)
	}
	measured := message(entry(token + ".tsujiura.ogadra.net."))
	stored := result{Token: token, ResolverIP: "192.0.2.1", QueriedAt: queriedAt, ExpiresAt: queriedAt.Add(24 * time.Hour)}
	withASN := stored
	withASN.ASN, withASN.ASOrganization = 64496, "Example"
	failure := errors.New("failure")

	tests := []struct {
		name      string
		data      string
		found     bool
		lookupErr error
		writeErr  error
		want      []result
		wantErr   bool
	}{
		{name: "known ASN", data: measured, found: true, want: []result{withASN}},
		{name: "unknown ASN", data: measured, want: []result{stored}},
		{name: "other name", data: message(entry("www.tsujiura.ogadra.net."))},
		{name: "broken entry", data: message("not json")},
		{name: "broken message", data: `"not a message"`, wantErr: true},
		{name: "lookup failure", data: measured, lookupErr: failure, wantErr: true},
		{name: "write failure", data: measured, found: true, writeErr: failure, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got []result
			in := &ingester{
				lookupASN: func(netip.Addr) (querylog.ASN, bool, error) {
					if !tt.found {
						return querylog.ASN{}, false, tt.lookupErr
					}
					return querylog.ASN{Number: 64496, Organization: "Example"}, true, nil
				},
				writeResult: func(_ context.Context, r result) error {
					if tt.writeErr != nil {
						return tt.writeErr
					}
					got = append(got, r)
					return nil
				},
			}

			e := event.New()
			if err := e.SetData(event.ApplicationJSON, json.RawMessage(tt.data)); err != nil {
				t.Fatal(err)
			}
			if err := in.ingest(context.Background(), e); (err != nil) != tt.wantErr {
				t.Fatalf("got error %v, want error: %t", err, tt.wantErr)
			}
			if fmt.Sprint(got) != fmt.Sprint(tt.want) {
				t.Errorf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}
