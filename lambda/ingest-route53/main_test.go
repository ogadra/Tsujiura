package main

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/base64"
	"encoding/json"
	"net/netip"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/ogadra/Tsujiura/internal/asn"
	"github.com/ogadra/Tsujiura/internal/ingest"
)

const tokenLine = "1.0 2017-12-13T08:16:02.130Z Z1 550e8400-e29b-41d4-a716-446655440000.tsujiura.ogadra.net A NOERROR UDP NRT57 192.0.2.1 -"

func encodeEvent(lines ...string) events.CloudwatchLogsEvent {
	data := events.CloudwatchLogsData{MessageType: "DATA_MESSAGE"}
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
	tests := []struct {
		name      string
		event     events.CloudwatchLogsEvent
		wantPuts  int
		wantError bool
	}{
		{"log event", encodeEvent(tokenLine), 1, false},
		{"not base64", events.CloudwatchLogsEvent{AWSLogs: events.CloudwatchLogsRawData{Data: "!"}}, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			puts := 0
			i := ingester{ingest.Ingester{
				Put:    func(context.Context, ingest.Item) error { puts++; return nil },
				Lookup: func(netip.Addr) (asn.AS, bool, error) { return asn.AS{}, false, nil },
			}}
			err := i.handle(context.Background(), tt.event)
			if (err != nil) != tt.wantError || puts != tt.wantPuts {
				t.Errorf("err = %v, puts = %d, want error %v, puts %d", err, puts, tt.wantError, tt.wantPuts)
			}
		})
	}
}
