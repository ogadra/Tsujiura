package main

import (
	"bytes"
	"context"
	"errors"
	"testing"

	"github.com/maxmind/mmdbwriter"
)

func emptyASNDB(t *testing.T) []byte {
	t.Helper()
	tree, err := mmdbwriter.New(mmdbwriter.Options{DatabaseType: "GeoLite2-ASN"})
	if err != nil {
		t.Fatal(err)
	}
	var data bytes.Buffer
	if _, err := tree.WriteTo(&data); err != nil {
		t.Fatal(err)
	}
	return data.Bytes()
}

func TestOpenASNDBReadsTheObjectFromTheBucket(t *testing.T) {
	data := emptyASNDB(t)
	var gotBucket, gotKey string
	read := func(_ context.Context, bucket, key string) ([]byte, error) {
		gotBucket, gotKey = bucket, key
		return data, nil
	}

	if _, err := openASNDB(context.Background(), read, "asn-bucket"); err != nil {
		t.Fatal(err)
	}
	if gotBucket != "asn-bucket" || gotKey != "GeoLite2-ASN.mmdb" {
		t.Errorf("read s3://%s/%s, want s3://asn-bucket/GeoLite2-ASN.mmdb", gotBucket, gotKey)
	}
}

func TestOpenASNDBFails(t *testing.T) {
	tests := []struct {
		name string
		read objectReader
	}{
		{"unreadable object", func(context.Context, string, string) ([]byte, error) { return nil, errors.New("access denied") }},
		{"not a database", func(context.Context, string, string) ([]byte, error) { return []byte("not a database"), nil }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := openASNDB(context.Background(), tt.read, "asn-bucket"); err == nil {
				t.Error("got no error")
			}
		})
	}
}
