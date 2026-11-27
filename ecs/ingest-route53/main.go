package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/ogadra/Tsujiura/internal/ingest"
	"github.com/ogadra/Tsujiura/internal/server"
)

const maxRequestBytes = 64 << 20

type firehoseRequest struct {
	RequestID string `json:"requestId"`
	Records   []struct {
		Data []byte `json:"data"`
	} `json:"records"`
}

type firehoseResponse struct {
	RequestID    string `json:"requestId"`
	Timestamp    int64  `json:"timestamp"`
	ErrorMessage string `json:"errorMessage,omitempty"`
}

type receiver struct {
	ingest func(context.Context, []byte) error
	now    func() time.Time
}

func (rc receiver) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, http.StatusText(http.StatusMethodNotAllowed), http.StatusMethodNotAllowed)
		return
	}
	var request firehoseRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequestBytes)).Decode(&request); err != nil {
		rc.respond(w, r, http.StatusBadRequest, request.RequestID, fmt.Errorf("decode firehose request: %w", err))
		return
	}
	for _, record := range request.Records {
		if err := rc.ingest(r.Context(), record.Data); err != nil {
			rc.respond(w, r, http.StatusInternalServerError, request.RequestID, err)
			return
		}
	}
	rc.respond(w, r, http.StatusOK, request.RequestID, nil)
}

func (rc receiver) respond(w http.ResponseWriter, r *http.Request, status int, requestID string, failure error) {
	response := firehoseResponse{RequestID: requestID, Timestamp: rc.now().UnixMilli()}
	if failure != nil {
		log.Printf("firehose request %s: %v", requestID, failure)
		response.ErrorMessage = failure.Error()
	}
	body, err := json.Marshal(response)
	if err != nil {
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Length", strconv.Itoa(len(body)))
	w.WriteHeader(status)
	if _, err := w.Write(body); err != nil {
		log.Printf("write response of firehose request %s: %v", requestID, err)
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
	table := mustEnv("RESULTS_TABLE_NAME")
	bucket := mustEnv("ASN_BUCKET")
	bucketRegion := mustEnv("ASN_BUCKET_REGION")

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, err
	}
	asns, err := ingest.OpenASNDB(ctx, ingest.S3ObjectReader(s3.NewFromConfig(cfg, func(o *s3.Options) { o.Region = bucketRegion })), bucket)
	if err != nil {
		return nil, err
	}
	client := dynamodb.NewFromConfig(cfg)
	return receiver{
		ingest: ingest.Ingester{
			Put: func(ctx context.Context, result ingest.Item) error {
				_, err := client.PutItem(ctx, &dynamodb.PutItemInput{TableName: aws.String(table), Item: result})
				return err
			},
			Lookup: asns.Lookup,
		}.Ingest,
		now: time.Now,
	}, nil
}

func main() {
	server.Serve(8082, newHandler)
}
