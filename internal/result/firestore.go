package result

import (
	"context"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Firestore reads the Cloud DNS records from a collection keyed by token.
type Firestore struct {
	Results *firestore.CollectionRef
}

// Has implements Reader.
func (f Firestore) Has(ctx context.Context, token string) (bool, error) {
	_, err := f.Results.Doc(token).Get(ctx)
	return exists(err)
}

// exists interprets the error of a document read.
func exists(err error) (bool, error) {
	if status.Code(err) == codes.NotFound {
		return false, nil
	}
	return err == nil, err
}
