// Package resultapi answers which DNS provider received a measurement token.
package resultapi

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sync"

	"cloud.google.com/go/compute/metadata"
	"cloud.google.com/go/firestore"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/sts"

	"github.com/ogadra/Tsujiura/internal/result"
)

// tokenAudience must match the oaud condition of the role's trust policy.
const tokenAudience = "sts.amazonaws.com"

// googleIDToken fetches the ID token of the function's service account.
type googleIDToken struct{}

// GetIdentityToken implements stscreds.IdentityTokenRetriever.
func (googleIDToken) GetIdentityToken() ([]byte, error) {
	token, err := metadata.GetWithContext(context.Background(), "instance/service-accounts/default/identity?audience="+tokenAudience)
	if err != nil {
		return nil, fmt.Errorf("fetch google id token: %w", err)
	}
	return []byte(token), nil
}

type api struct {
	respond func(ctx context.Context, token string) (int, []byte)
}

var defaultAPI = sync.OnceValues(newAPI)

func init() {
	functions.HTTP("ResultAPI", func(w http.ResponseWriter, r *http.Request) {
		a, err := defaultAPI()
		if err != nil {
			slog.ErrorContext(r.Context(), "create result api", "error", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		a.handle(w, r)
	})
}

func newDynamoDB(roleARN, region string) *dynamodb.Client {
	provider := stscreds.NewWebIdentityRoleProvider(sts.New(sts.Options{Region: region}), roleARN, googleIDToken{})
	return dynamodb.New(dynamodb.Options{Region: region, Credentials: aws.NewCredentialsCache(provider)})
}

func newAPI() (*api, error) {
	collection := os.Getenv("FIRESTORE_COLLECTION")
	if collection == "" {
		return nil, errors.New("FIRESTORE_COLLECTION is not set")
	}
	table := os.Getenv("RESULTS_TABLE_NAME")
	if table == "" {
		return nil, errors.New("RESULTS_TABLE_NAME is not set")
	}
	region := os.Getenv("RESULTS_TABLE_REGION")
	if region == "" {
		return nil, errors.New("RESULTS_TABLE_REGION is not set")
	}
	roleARN := os.Getenv("RESULTS_TABLE_ROLE_ARN")
	if roleARN == "" {
		return nil, errors.New("RESULTS_TABLE_ROLE_ARN is not set")
	}
	client, err := firestore.NewClient(context.Background(), firestore.DetectProjectID)
	if err != nil {
		return nil, fmt.Errorf("create firestore client: %w", err)
	}

	return &api{respond: result.Aggregator{
		DynamoDB:  result.DynamoDB{GetItem: newDynamoDB(roleARN, region).GetItem, Table: table},
		Firestore: result.Firestore{Results: client.Collection(collection)},
	}.Respond}, nil
}

func (a *api) handle(w http.ResponseWriter, r *http.Request) {
	status, body := a.respond(r.Context(), r.URL.Query().Get("token"))
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if _, err := w.Write(body); err != nil {
		slog.ErrorContext(r.Context(), "write response", "error", err)
	}
}
