package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"cloud.google.com/go/auth/credentials/externalaccount"
	"github.com/aws/aws-sdk-go-v2/aws"
	awscredentials "github.com/aws/aws-sdk-go-v2/credentials"
)

func TestGoogleCredentialsExchangeTaskRoleCredentials(t *testing.T) {
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

	cfg := aws.Config{Region: "ap-northeast-1", Credentials: awscredentials.NewStaticCredentialsProvider("id", "secret", "session")}
	options := googleCredentials(cfg, "//iam.googleapis.com/pool", "reader@example.iam.gserviceaccount.com")
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

func TestTaskRoleRequiresRegion(t *testing.T) {
	if _, err := (taskRole{aws.Config{}}).AwsRegion(context.Background(), nil); err == nil {
		t.Error("got no error without a region")
	}
}
