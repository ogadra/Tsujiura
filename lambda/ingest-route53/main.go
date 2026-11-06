// Command ingest-route53 stores Route53 query logs in DynamoDB.
package main

import (
	"context"
	"fmt"
	"log"
	"net/netip"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/ogadra/Tsujiura/internal/querylog"
)

type item = map[string]types.AttributeValue

type ingester struct {
	put    func(context.Context, item) error
	lookup func(netip.Addr) (querylog.ASN, bool, error)
}

// handle is safe to retry because items are keyed by token.
func (i ingester) handle(ctx context.Context, event events.CloudwatchLogsEvent) error {
	data, err := event.AWSLogs.Parse()
	if err != nil {
		return fmt.Errorf("decode log event: %w", err)
	}
	// CloudWatch Logs sends a CONTROL_MESSAGE to check that the destination is reachable.
	if data.MessageType != "DATA_MESSAGE" {
		return nil
	}

	for _, logEvent := range data.LogEvents {
		query, ok, err := querylog.ParseRoute53(logEvent.Message)
		if err != nil {
			log.Printf("skip log event %s: %v", logEvent.ID, err)
		}
		if !ok {
			continue
		}

		result := item{
			"token":      &types.AttributeValueMemberS{Value: query.Token},
			"resolverIp": &types.AttributeValueMemberS{Value: query.ResolverIP.String()},
			"queriedAt":  &types.AttributeValueMemberS{Value: query.Time.UTC().Format(time.RFC3339Nano)},
			"expiresAt":  &types.AttributeValueMemberN{Value: strconv.FormatInt(query.Time.AddDate(0, 0, 1).Unix(), 10)},
		}
		asn, ok, err := i.lookup(query.ResolverIP)
		if err != nil {
			return err
		}
		if ok {
			result["asn"] = &types.AttributeValueMemberN{Value: strconv.FormatUint(uint64(asn.Number), 10)}
			result["asOrganization"] = &types.AttributeValueMemberS{Value: asn.Organization}
		}
		if err := i.put(ctx, result); err != nil {
			return fmt.Errorf("put result of %s: %w", query.Token, err)
		}
	}
	return nil
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
	asns, err := querylog.OpenASNDB(requireEnv("ASN_DB_PATH"))
	if err != nil {
		log.Fatal(err)
	}
	// The Lambda runs next to the log group in us-east-1, which is not the region of the table.
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(requireEnv("RESULTS_TABLE_REGION")))
	if err != nil {
		log.Fatal(err)
	}
	client := dynamodb.NewFromConfig(cfg)

	lambda.Start(ingester{
		put: func(ctx context.Context, result item) error {
			_, err := client.PutItem(ctx, &dynamodb.PutItemInput{TableName: aws.String(table), Item: result})
			return err
		},
		lookup: asns.Lookup,
	}.handle)
}
