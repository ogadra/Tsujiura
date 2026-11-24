package main

import (
	"context"
	"fmt"
	"io"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/ogadra/Tsujiura/internal/asn"
)

const asnObjectKey = "GeoLite2-ASN.mmdb"

type objectReader func(ctx context.Context, bucket, key string) ([]byte, error)

func openASNDB(ctx context.Context, read objectReader, bucket string) (*asn.DB, error) {
	data, err := read(ctx, bucket, asnObjectKey)
	if err != nil {
		return nil, fmt.Errorf("read s3://%s/%s: %w", bucket, asnObjectKey, err)
	}
	return asn.New(data)
}

func s3ObjectReader(client *s3.Client) objectReader {
	return func(ctx context.Context, bucket, key string) ([]byte, error) {
		out, err := client.GetObject(ctx, &s3.GetObjectInput{Bucket: aws.String(bucket), Key: aws.String(key)})
		if err != nil {
			return nil, err
		}
		defer out.Body.Close()
		return io.ReadAll(out.Body)
	}
}
