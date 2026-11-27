package main

import (
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/ogadra/Tsujiura/internal/ingest"
)

type ingester struct{ ingest.Ingester }

func (i ingester) handle(ctx context.Context, event events.CloudwatchLogsEvent) error {
	compressed, err := base64.StdEncoding.DecodeString(event.AWSLogs.Data)
	if err != nil {
		return fmt.Errorf("decode log event: %w", err)
	}
	return i.Ingest(ctx, compressed)
}

func requireEnv(name string) string {
	value := os.Getenv(name)
	if value == "" {
		log.Fatalf("%s must be set", name)
	}
	return value
}

func main() {
	table := requireEnv("RESULTS_TABLE_NAME")
	tableRegion := requireEnv("RESULTS_TABLE_REGION")
	bucket := requireEnv("ASN_BUCKET")

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatal(err)
	}
	asns, err := ingest.OpenASNDB(ctx, ingest.S3ObjectReader(s3.NewFromConfig(cfg)), bucket)
	if err != nil {
		log.Fatal(err)
	}
	// The Lambda runs next to the log group in us-east-1, which is not the region of the table.
	client := dynamodb.NewFromConfig(cfg, func(o *dynamodb.Options) { o.Region = tableRegion })

	lambda.Start(ingester{ingest.Ingester{
		Put: func(ctx context.Context, result ingest.Item) error {
			_, err := client.PutItem(ctx, &dynamodb.PutItemInput{TableName: aws.String(table), Item: result})
			return err
		},
		Lookup: asns.Lookup,
	}}.handle)
}
