package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"

	"cloud.google.com/go/auth/credentials/externalaccount"
	"cloud.google.com/go/firestore"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/ogadra/Tsujiura/internal/result"
	"github.com/ogadra/Tsujiura/internal/server"
	"google.golang.org/api/option"
)

type taskRole struct{ aws.Config }

func (r taskRole) AwsRegion(context.Context, *externalaccount.RequestOptions) (string, error) {
	if r.Region == "" {
		return "", errors.New("AWS region is not set")
	}
	return r.Region, nil
}

func (r taskRole) AwsSecurityCredentials(ctx context.Context, _ *externalaccount.RequestOptions) (*externalaccount.AwsSecurityCredentials, error) {
	credentials, err := r.Credentials.Retrieve(ctx)
	if err != nil {
		return nil, err
	}
	return &externalaccount.AwsSecurityCredentials{
		AccessKeyID:     credentials.AccessKeyID,
		SecretAccessKey: credentials.SecretAccessKey,
		SessionToken:    credentials.SessionToken,
	}, nil
}

func googleCredentials(cfg aws.Config, audience, serviceAccount string) *externalaccount.Options {
	return &externalaccount.Options{
		Audience:                       audience,
		SubjectTokenType:               "urn:ietf:params:aws:token-type:aws4_request",
		ServiceAccountImpersonationURL: "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/" + serviceAccount + ":generateAccessToken",
		AwsSecurityCredentialsProvider: taskRole{cfg},
		Scopes:                         []string{"https://www.googleapis.com/auth/datastore"},
	}
}

func mustEnv(name string) string {
	value := os.Getenv(name)
	if value == "" {
		log.Fatalf("%s must be set", name)
	}
	return value
}

func newHandler() (http.Handler, error) {
	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, err
	}
	credentials, err := externalaccount.NewCredentials(googleCredentials(cfg, mustEnv("GOOGLE_WORKLOAD_IDENTITY_AUDIENCE"), mustEnv("GOOGLE_SERVICE_ACCOUNT")))
	if err != nil {
		return nil, err
	}
	client, err := firestore.NewClient(ctx, mustEnv("GOOGLE_CLOUD_PROJECT"), option.WithAuthCredentials(credentials))
	if err != nil {
		return nil, err
	}
	return result.Aggregator{
		DynamoDB:  result.DynamoDB{GetItem: dynamodb.NewFromConfig(cfg).GetItem, Table: mustEnv("RESULTS_TABLE_NAME")},
		Firestore: result.Firestore{Results: client.Collection(mustEnv("FIRESTORE_COLLECTION"))},
	}, nil
}

func main() {
	server.Serve(8081, newHandler)
}
