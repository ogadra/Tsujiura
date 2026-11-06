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

	"cloud.google.com/go/firestore"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"

	"github.com/ogadra/Tsujiura/internal/result"
)

// unreadableDynamoDB stands in until the function can authenticate to AWS.
type unreadableDynamoDB struct{}

func (unreadableDynamoDB) Has(context.Context, string) (bool, error) {
	return false, errors.New("dynamodb is not readable from Google Cloud yet")
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

func newAPI() (*api, error) {
	collection := os.Getenv("FIRESTORE_COLLECTION")
	if collection == "" {
		return nil, errors.New("FIRESTORE_COLLECTION is not set")
	}
	client, err := firestore.NewClient(context.Background(), firestore.DetectProjectID)
	if err != nil {
		return nil, fmt.Errorf("create firestore client: %w", err)
	}

	return &api{respond: result.Aggregator{
		DynamoDB:  unreadableDynamoDB{},
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
