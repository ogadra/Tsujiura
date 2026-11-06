package main

import (
	"strings"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestHandle(t *testing.T) {
	tests := []struct {
		path, contentType, body string
		status                  int
	}{
		{"/", "text/html; charset=utf-8", "<title>Tsujiura</title>", 200},
		{"/main.js", "text/javascript; charset=utf-8", "crypto.randomUUID()", 200},
		{"/missing", "", "", 404},
	}
	for _, tt := range tests {
		got, err := site{"../../web"}.handle(events.ALBTargetGroupRequest{Path: tt.path})
		if err != nil {
			t.Fatal(err)
		}
		if got.StatusCode != tt.status || got.Headers["Content-Type"] != tt.contentType || !strings.Contains(got.Body, tt.body) {
			t.Errorf("%s: got %+v", tt.path, got)
		}
	}
}
