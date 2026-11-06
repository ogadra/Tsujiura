// Package ingestclouddns stores the Cloud DNS query logs delivered by Pub/Sub in Firestore.
package ingestclouddns

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/netip"
	"os"
	"sync"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/cloudevents/sdk-go/v2/event"

	"github.com/ogadra/Tsujiura/internal/querylog"
)

const resultTTL = 24 * time.Hour

// result is the Firestore document of a token.
type result struct {
	Token          string    `firestore:"token"`
	ResolverIP     string    `firestore:"resolverIp"`
	QueriedAt      time.Time `firestore:"queriedAt"`
	ASN            int64     `firestore:"asn,omitempty"`
	ASOrganization string    `firestore:"asOrganization,omitempty"`
	ExpiresAt      time.Time `firestore:"expiresAt"`
}

type ingester struct {
	lookupASN   func(netip.Addr) (querylog.ASN, bool, error)
	writeResult func(context.Context, result) error
}

var defaultIngester = sync.OnceValues(newIngester)

func init() {
	functions.CloudEvent("IngestCloudDNS", func(ctx context.Context, e event.Event) error {
		in, err := defaultIngester()
		if err != nil {
			return err
		}
		return in.ingest(ctx, e)
	})
}

func newIngester() (*ingester, error) {
	collection := os.Getenv("FIRESTORE_COLLECTION")
	if collection == "" {
		return nil, errors.New("FIRESTORE_COLLECTION is not set")
	}
	asnDBPath := os.Getenv("ASN_DB_PATH")
	if asnDBPath == "" {
		return nil, errors.New("ASN_DB_PATH is not set")
	}

	asnDB, err := querylog.OpenASNDB(asnDBPath)
	if err != nil {
		return nil, err
	}
	client, err := firestore.NewClient(context.Background(), firestore.DetectProjectID)
	if err != nil {
		return nil, fmt.Errorf("create firestore client: %w", err)
	}

	results := client.Collection(collection)
	return &ingester{
		lookupASN: asnDB.Lookup,
		writeResult: func(ctx context.Context, r result) error {
			_, err := results.Doc(r.Token).Set(ctx, r)
			return err
		},
	}, nil
}

// ingest stores the query of one Pub/Sub message.
// A log entry that cannot be parsed is dropped because redelivery would not fix it.
func (in *ingester) ingest(ctx context.Context, e event.Event) error {
	var data struct {
		Message struct {
			Data []byte `json:"data"`
		} `json:"message"`
	}
	if err := e.DataAs(&data); err != nil {
		return fmt.Errorf("decode pub/sub message: %w", err)
	}

	query, ok, err := querylog.ParseCloudDNS(data.Message.Data)
	if err != nil {
		slog.ErrorContext(ctx, "drop query log entry", "error", err)
		return nil
	}
	if !ok {
		return nil
	}

	asn, _, err := in.lookupASN(query.ResolverIP)
	if err != nil {
		return err
	}

	return in.writeResult(ctx, result{
		Token:          query.Token,
		ResolverIP:     query.ResolverIP.String(),
		QueriedAt:      query.Time,
		ASN:            int64(asn.Number),
		ASOrganization: asn.Organization,
		ExpiresAt:      query.Time.Add(resultTTL),
	})
}
