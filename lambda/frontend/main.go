// Command frontend serves the measurement page behind the ALB.
package main

import (
	"net/http"
	"os"
	"path/filepath"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

var assets = map[string]struct{ file, contentType string }{
	"/":        {"index.html", "text/html; charset=utf-8"},
	"/main.js": {"main.js", "text/javascript; charset=utf-8"},
}

type site struct{ dir string }

func (s site) handle(request events.ALBTargetGroupRequest) (events.ALBTargetGroupResponse, error) {
	asset, ok := assets[request.Path]
	if !ok {
		return events.ALBTargetGroupResponse{StatusCode: http.StatusNotFound, StatusDescription: "404 Not Found"}, nil
	}
	body, err := os.ReadFile(filepath.Join(s.dir, asset.file))
	if err != nil {
		return events.ALBTargetGroupResponse{}, err
	}
	return events.ALBTargetGroupResponse{
		StatusCode:        http.StatusOK,
		StatusDescription: "200 OK",
		Headers:           map[string]string{"Content-Type": asset.contentType},
		Body:              string(body),
	}, nil
}

func main() {
	lambda.Start(site{"web"}.handle)
}
