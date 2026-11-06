package main

import (
	"context"
	"reflect"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/ogadra/Tsujiura/internal/result"
)

type reader struct{}

func (reader) Has(context.Context, string) (bool, error) { return true, nil }

func TestHandleAnswersFirestoreUnavailable(t *testing.T) {
	request := events.ALBTargetGroupRequest{QueryStringParameters: map[string]string{"token": "550e8400-e29b-41d4-a716-446655440000"}}
	got, err := api{result.Aggregator{DynamoDB: reader{}, Firestore: unreadableFirestore{}}}.handle(context.Background(), request)
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
