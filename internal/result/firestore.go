package result

import (
	"context"
	"fmt"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Firestore reads the Cloud DNS records from a collection keyed by token.
type Firestore struct {
	Results *firestore.CollectionRef
}

// Get implements Reader.
func (f Firestore) Get(ctx context.Context, token string) (*Record, error) {
	snapshot, err := f.Results.Doc(token).Get(ctx)
	if found, err := exists(err); !found {
		return nil, err
	}
	record := &Record{}
	if err := snapshot.DataTo(record); err != nil {
		return nil, fmt.Errorf("decode the record of %s: %w", token, err)
	}
	return record, nil
}

// exists interprets the error of a document read.
func exists(err error) (bool, error) {
	if status.Code(err) == codes.NotFound {
		return false, nil
	}
	return err == nil, err
}
