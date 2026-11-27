package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/ogadra/Tsujiura/web"
)

type site struct{ handler http.Handler }

func (s site) handle(ctx context.Context, request events.ALBTargetGroupRequest) (events.ALBTargetGroupResponse, error) {
	r, err := http.NewRequestWithContext(ctx, request.HTTPMethod, request.Path, strings.NewReader(request.Body))
	if err != nil {
		return events.ALBTargetGroupResponse{}, err
	}
	w := httptest.NewRecorder()
	s.handler.ServeHTTP(w, r)
	headers := make(map[string]string, len(w.Header()))
	for name := range w.Header() {
		headers[name] = w.Header().Get(name)
	}
	return events.ALBTargetGroupResponse{
		StatusCode:        w.Code,
		StatusDescription: fmt.Sprintf("%d %s", w.Code, http.StatusText(w.Code)),
		Headers:           headers,
		Body:              w.Body.String(),
	}, nil
}

func main() {
	h, err := web.Handler("aws")
	if err != nil {
		log.Fatal(err)
	}
	lambda.Start(site{h}.handle)
}
