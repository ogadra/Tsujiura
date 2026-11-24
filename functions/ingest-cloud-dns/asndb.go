package ingestclouddns

import (
	"context"
	"fmt"
	"io"

	"cloud.google.com/go/storage"

	"github.com/ogadra/Tsujiura/internal/asn"
)

const asnObjectKey = "GeoLite2-ASN.mmdb"

type objectReader func(ctx context.Context, bucket, key string) ([]byte, error)

func openASNDB(ctx context.Context, read objectReader, bucket string) (*asn.DB, error) {
	data, err := read(ctx, bucket, asnObjectKey)
	if err != nil {
		return nil, fmt.Errorf("read gs://%s/%s: %w", bucket, asnObjectKey, err)
	}
	return asn.New(data)
}

func gcsObjectReader(client *storage.Client) objectReader {
	return func(ctx context.Context, bucket, key string) ([]byte, error) {
		r, err := client.Bucket(bucket).Object(key).NewReader(ctx)
		if err != nil {
			return nil, err
		}
		defer r.Close()
		return io.ReadAll(r)
	}
}
