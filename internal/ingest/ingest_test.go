package ingest

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"errors"
	"maps"
	"net/netip"
	"reflect"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/ogadra/Tsujiura/internal/asn"
)

const token = "550e8400-e29b-41d4-a716-446655440000"
const tokenLine = "1.0 2017-12-13T08:16:02.130Z Z1 " + token + ".tsujiura.ogadra.net A NOERROR UDP NRT57 192.0.2.1 -"

func compress(messageType string, lines ...string) []byte {
	data := logsData{MessageType: messageType}
	for _, line := range lines {
		data.LogEvents = append(data.LogEvents, logEvent{Message: line})
	}
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	json.NewEncoder(zw).Encode(data)
	zw.Close()
	return buf.Bytes()
}

func TestIngest(t *testing.T) {
	unknown := func(netip.Addr) (asn.AS, bool, error) { return asn.AS{}, false, nil }
	example := asn.AS{Number: 64496, Organization: "Example"}
	known := func(netip.Addr) (asn.AS, bool, error) { return example, true, nil }
	broken := func(netip.Addr) (asn.AS, bool, error) { return asn.AS{}, false, errors.New("failure") }

	withoutASN := Item{
		"token":      &types.AttributeValueMemberS{Value: token},
		"resolverIp": &types.AttributeValueMemberS{Value: "192.0.2.1"},
		"queriedAt":  &types.AttributeValueMemberS{Value: "2017-12-13T08:16:02.13Z"},
		"expiresAt":  &types.AttributeValueMemberN{Value: "1513239362"},
	}
	withASN := maps.Clone(withoutASN)
	withASN["asn"] = &types.AttributeValueMemberN{Value: "64496"}
	withASN["asOrganization"] = &types.AttributeValueMemberS{Value: "Example"}

	tests := []struct {
		name       string
		compressed []byte
		lookup     func(netip.Addr) (asn.AS, bool, error)
		putErr     error
		want       []Item
		wantErr    bool
	}{
		{name: "known ASN", compressed: compress("DATA_MESSAGE", tokenLine), lookup: known, want: []Item{withASN}},
		{name: "unknown ASN", compressed: compress("DATA_MESSAGE", tokenLine), lookup: unknown, want: []Item{withoutASN}},
		{name: "malformed line keeps the batch", compressed: compress("DATA_MESSAGE", "broken", tokenLine), lookup: unknown, want: []Item{withoutASN}},
		{name: "other name", compressed: compress("DATA_MESSAGE", "1.0 2017-12-13T08:16:02.130Z Z1 tsujiura.ogadra.net A NOERROR UDP NRT57 192.0.2.1 -"), lookup: unknown},
		{name: "control message", compressed: compress("CONTROL_MESSAGE", "CWL CONTROL MESSAGE: Checking health of destination"), lookup: unknown},
		{name: "not gzip", compressed: []byte("plain"), lookup: unknown, wantErr: true},
		{name: "not json", compressed: gzipped(t, "plain"), lookup: unknown, wantErr: true},
		{name: "failed lookup", compressed: compress("DATA_MESSAGE", tokenLine), lookup: broken, wantErr: true},
		{name: "failed write", compressed: compress("DATA_MESSAGE", tokenLine), lookup: unknown, putErr: errors.New("failure"), want: []Item{withoutASN}, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got []Item
			put := func(_ context.Context, result Item) error {
				got = append(got, result)
				return tt.putErr
			}
			err := Ingester{Put: put, Lookup: tt.lookup}.Ingest(context.Background(), tt.compressed)
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}

func gzipped(t *testing.T, s string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	if _, err := zw.Write([]byte(s)); err != nil {
		t.Fatal(err)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}
