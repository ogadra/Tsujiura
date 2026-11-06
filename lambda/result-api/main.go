// Command result-api answers which DNS provider received a measurement token.
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"cloud.google.com/go/auth/credentials/externalaccount"
	"cloud.google.com/go/firestore"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/ogadra/Tsujiura/internal/result"
	"google.golang.org/api/option"
)

// googleCredentials exchanges the AWS credentials in the Lambda environment for a service account token.
func googleCredentials(audience, serviceAccount string) *externalaccount.Options {
	return &externalaccount.Options{
		Audience:                       audience,
		SubjectTokenType:               "urn:ietf:params:aws:token-type:aws4_request",
		ServiceAccountImpersonationURL: "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/" + serviceAccount + ":generateAccessToken",
		CredentialSource:               &externalaccount.CredentialSource{EnvironmentID: "aws1"},
		Scopes:                         []string{"https://www.googleapis.com/auth/datastore"},
	}
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

func mustEnv(name string) string {
	value := os.Getenv(name)
	if value == "" {
		log.Fatalf("%s must be set", name)
	}
	return value
}

func main() {
	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatal(err)
	}
	credentials, err := externalaccount.NewCredentials(googleCredentials(mustEnv("GOOGLE_WORKLOAD_IDENTITY_AUDIENCE"), mustEnv("GOOGLE_SERVICE_ACCOUNT")))
	if err != nil {
		log.Fatal(err)
	}
	client, err := firestore.NewClient(ctx, mustEnv("GOOGLE_CLOUD_PROJECT"), option.WithAuthCredentials(credentials))
	if err != nil {
		log.Fatal(err)
	}
	lambda.Start(api{result.Aggregator{
		DynamoDB:  result.DynamoDB{GetItem: dynamodb.NewFromConfig(cfg).GetItem, Table: mustEnv("RESULTS_TABLE_NAME")},
		Firestore: result.Firestore{Results: client.Collection(mustEnv("FIRESTORE_COLLECTION"))},
	}}.handle)
}
