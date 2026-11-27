package main

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-lambda-go/events"

	"github.com/ogadra/Tsujiura/web"
)

func TestHandle(t *testing.T) {
	h, err := web.Handler("aws")
	if err != nil {
		t.Fatal(err)
	}
	tests := []struct {
		path, contentType, body, description string
		status                               int
	}{
		{"/", "text/html; charset=utf-8", "<title>Tsujiura</title>", "200 OK", 200},
		{"/provider.svg", "image/svg+xml", `width="1"`, "200 OK", 200},
		{"/missing", "", "", "404 Not Found", 404},
	}
	for _, tt := range tests {
		got, err := site{h}.handle(context.Background(), events.ALBTargetGroupRequest{HTTPMethod: "GET", Path: tt.path})
		if err != nil {
			t.Fatal(err)
		}
		if got.StatusCode != tt.status || got.StatusDescription != tt.description || got.Headers["Content-Type"] != tt.contentType || !strings.Contains(got.Body, tt.body) {
			t.Errorf("%s: got %+v", tt.path, got)
		}
	}
}
