// Command result-api answers which DNS provider received a measurement token.
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/ogadra/Tsujiura/internal/result"
)

// unreadableFirestore stands in until the Lambda can authenticate to Google Cloud.
type unreadableFirestore struct{}

func (unreadableFirestore) Has(context.Context, string) (bool, error) {
	return false, errors.New("firestore is not readable from AWS yet")
}

type api struct{ result.Aggregator }

func (a api) handle(ctx context.Context, request events.ALBTargetGroupRequest) (events.ALBTargetGroupResponse, error) {
	status, body := a.Respond(ctx, request.QueryStringParameters["token"])
	return events.ALBTargetGroupResponse{
		StatusCode:        status,
		StatusDescription: fmt.Sprintf("%d %s", status, http.StatusText(status)),
		Headers:           map[string]string{"Content-Type": "application/json"},
		Body:              string(body),
	}, nil
}

func main() {
	table := os.Getenv("RESULTS_TABLE_NAME")
	if table == "" {
		log.Fatal("RESULTS_TABLE_NAME must be set")
	}
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	lambda.Start(api{result.Aggregator{
		DynamoDB:  result.DynamoDB{GetItem: dynamodb.NewFromConfig(cfg).GetItem, Table: table},
		Firestore: unreadableFirestore{},
	}}.handle)
}
