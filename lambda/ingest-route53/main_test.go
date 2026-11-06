package main

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"maps"
	"net/netip"
	"reflect"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/ogadra/Tsujiura/internal/querylog"
)

const token = "550e8400-e29b-41d4-a716-446655440000"
const tokenLine = "1.0 2017-12-13T08:16:02.130Z Z1 " + token + ".tsujiura.ogadra.net A NOERROR UDP NRT57 192.0.2.1 -"

func encodeEvent(messageType string, lines ...string) events.CloudwatchLogsEvent {
	data := events.CloudwatchLogsData{MessageType: messageType}
	for _, line := range lines {
		data.LogEvents = append(data.LogEvents, events.CloudwatchLogsLogEvent{Message: line})
	}
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	json.NewEncoder(zw).Encode(data)
	zw.Close()
	return events.CloudwatchLogsEvent{AWSLogs: events.CloudwatchLogsRawData{Data: base64.StdEncoding.EncodeToString(buf.Bytes())}}
}

func TestHandle(t *testing.T) {
	unknown := func(netip.Addr) (querylog.ASN, bool, error) { return querylog.ASN{}, false, nil }
	example := querylog.ASN{Number: 64496, Organization: "Example"}
	known := func(netip.Addr) (querylog.ASN, bool, error) { return example, true, nil }
	broken := func(netip.Addr) (querylog.ASN, bool, error) { return querylog.ASN{}, false, errors.New("failure") }

	withoutASN := item{
		"token":      &types.AttributeValueMemberS{Value: token},
		"resolverIp": &types.AttributeValueMemberS{Value: "192.0.2.1"},
		"queriedAt":  &types.AttributeValueMemberS{Value: "2017-12-13T08:16:02.13Z"},
		"expiresAt":  &types.AttributeValueMemberN{Value: "1513239362"},
	}
	withASN := maps.Clone(withoutASN)
	withASN["asn"] = &types.AttributeValueMemberN{Value: "64496"}
	withASN["asOrganization"] = &types.AttributeValueMemberS{Value: "Example"}

	tests := []struct {
		name    string
		event   events.CloudwatchLogsEvent
		lookup  func(netip.Addr) (querylog.ASN, bool, error)
		putErr  error
		want    []item
		wantErr bool
	}{
		{name: "known ASN", event: encodeEvent("DATA_MESSAGE", tokenLine), lookup: known, want: []item{withASN}},
		{name: "unknown ASN", event: encodeEvent("DATA_MESSAGE", tokenLine), lookup: unknown, want: []item{withoutASN}},
		{name: "malformed line keeps the batch", event: encodeEvent("DATA_MESSAGE", "broken", tokenLine), lookup: unknown, want: []item{withoutASN}},
		{name: "other name", event: encodeEvent("DATA_MESSAGE", "1.0 2017-12-13T08:16:02.130Z Z1 tsujiura.ogadra.net A NOERROR UDP NRT57 192.0.2.1 -"), lookup: unknown},
		{name: "control message", event: encodeEvent("CONTROL_MESSAGE", "CWL CONTROL MESSAGE: Checking health of destination"), lookup: unknown},
		{name: "undecodable event", event: events.CloudwatchLogsEvent{AWSLogs: events.CloudwatchLogsRawData{Data: "!"}}, lookup: unknown, wantErr: true},
		{name: "failed lookup", event: encodeEvent("DATA_MESSAGE", tokenLine), lookup: broken, wantErr: true},
		{name: "failed write", event: encodeEvent("DATA_MESSAGE", tokenLine), lookup: unknown, putErr: errors.New("failure"), want: []item{withoutASN}, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got []item
			put := func(_ context.Context, result item) error {
				got = append(got, result)
				return tt.putErr
			}
			err := ingester{put: put, lookup: tt.lookup}.handle(context.Background(), tt.event)
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}
