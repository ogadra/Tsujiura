package ingest

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/netip"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/ogadra/Tsujiura/internal/asn"
)

type Item = map[string]types.AttributeValue

type Ingester struct {
	Put    func(context.Context, Item) error
	Lookup func(netip.Addr) (asn.AS, bool, error)
}

type logsData struct {
	MessageType string     `json:"messageType"`
	LogEvents   []logEvent `json:"logEvents"`
}

type logEvent struct {
	ID      string `json:"id"`
	Message string `json:"message"`
}

// Ingest is safe to retry because items are keyed by token.
func (i Ingester) Ingest(ctx context.Context, compressed []byte) error {
	zr, err := gzip.NewReader(bytes.NewReader(compressed))
	if err != nil {
		return fmt.Errorf("decompress log events: %w", err)
	}
	var data logsData
	if err := json.NewDecoder(zr).Decode(&data); err != nil {
		return fmt.Errorf("decode log events: %w", err)
	}
	// CloudWatch Logs sends a CONTROL_MESSAGE to check that the destination is reachable.
	if data.MessageType != "DATA_MESSAGE" {
		return nil
	}

	for _, logEvent := range data.LogEvents {
		query, ok, err := parseQueryLog(logEvent.Message)
		if err != nil {
			log.Printf("skip log event %s: %v", logEvent.ID, err)
		}
		if !ok {
			continue
		}

		result := Item{
			"token":      &types.AttributeValueMemberS{Value: query.Token},
			"resolverIp": &types.AttributeValueMemberS{Value: query.ResolverIP.String()},
			"queriedAt":  &types.AttributeValueMemberS{Value: query.Time.UTC().Format(time.RFC3339Nano)},
			"expiresAt":  &types.AttributeValueMemberN{Value: strconv.FormatInt(query.Time.AddDate(0, 0, 1).Unix(), 10)},
		}
		asn, ok, err := i.Lookup(query.ResolverIP)
		if err != nil {
			return err
		}
		if ok {
			result["asn"] = &types.AttributeValueMemberN{Value: strconv.FormatUint(uint64(asn.Number), 10)}
			result["asOrganization"] = &types.AttributeValueMemberS{Value: asn.Organization}
		}
		if err := i.Put(ctx, result); err != nil {
			return fmt.Errorf("put result of %s: %w", query.Token, err)
		}
	}
	return nil
}
