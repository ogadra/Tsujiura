package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"reflect"
	"strings"
	"testing"

	"cloud.google.com/go/auth/credentials/externalaccount"
	"github.com/aws/aws-lambda-go/events"
	"github.com/ogadra/Tsujiura/internal/result"
)

type reader struct{}

func (reader) Has(context.Context, string) (bool, error) { return true, nil }

type unreadable struct{}

func (unreadable) Has(context.Context, string) (bool, error) { return false, errors.New("unreadable") }

func TestHandleAnswersFirestoreUnavailable(t *testing.T) {
	request := events.ALBTargetGroupRequest{QueryStringParameters: map[string]string{"token": "550e8400-e29b-41d4-a716-446655440000"}}
	got, err := api{result.Aggregator{DynamoDB: reader{}, Firestore: unreadable{}}}.handle(context.Background(), request)
	if err != nil {
		t.Fatal(err)
	}
	want := events.ALBTargetGroupResponse{
		StatusCode:        503,
		StatusDescription: "503 Service Unavailable",
		Headers:           map[string]string{"Content-Type": "application/json"},
		Body:              `{"unavailable":["Firestore"]}`,
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v, want %+v", got, want)
	}
}

func TestGoogleCredentialsExchangeLambdaEnvironment(t *testing.T) {
	t.Setenv("AWS_REGION", "ap-northeast-1")
	t.Setenv("AWS_ACCESS_KEY_ID", "id")
	t.Setenv("AWS_SECRET_ACCESS_KEY", "secret")
	t.Setenv("AWS_SESSION_TOKEN", "session")

	var subjectToken, authorization string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/sts" {
			subjectToken = r.FormValue("subject_token")
			json.NewEncoder(w).Encode(map[string]any{"access_token": "federated", "token_type": "Bearer", "expires_in": 3600})
			return
		}
		authorization = r.Header.Get("Authorization")
		json.NewEncoder(w).Encode(map[string]string{"accessToken": "impersonated", "expireTime": "2100-01-01T00:00:00Z"})
	}))
	defer server.Close()

	options := googleCredentials("//iam.googleapis.com/pool", "reader@example.iam.gserviceaccount.com")
	if !strings.HasSuffix(options.ServiceAccountImpersonationURL, "/serviceAccounts/reader@example.iam.gserviceaccount.com:generateAccessToken") {
		t.Errorf("impersonation url = %q", options.ServiceAccountImpersonationURL)
	}
	options.TokenURL = server.URL + "/sts"
	options.ServiceAccountImpersonationURL = server.URL + "/impersonate"
	credentials, err := externalaccount.NewCredentials(options)
	if err != nil {
		t.Fatal(err)
	}
	token, err := credentials.Token(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if token.Value != "impersonated" || authorization != "Bearer federated" {
		t.Errorf("token = %q, impersonation authorization = %q", token.Value, authorization)
	}
	decoded, err := url.QueryUnescape(subjectToken)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"sts.ap-northeast-1.amazonaws.com", "x-goog-cloud-target-resource", "session"} {
		if !strings.Contains(decoded, want) {
			t.Errorf("subject token %q does not contain %q", decoded, want)
		}
	}
}
