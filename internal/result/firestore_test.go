package result

import (
	"errors"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestExists(t *testing.T) {
	denied := status.Error(codes.PermissionDenied, "denied")
	tests := []struct {
		name    string
		err     error
		want    bool
		wantErr error
	}{
		{"found", nil, true, nil},
		{"missing", status.Error(codes.NotFound, "missing"), false, nil},
		{"denied", denied, false, denied},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := exists(tt.err)
			if got != tt.want || !errors.Is(err, tt.wantErr) {
				t.Errorf("got %t, %v, want %t, %v", got, err, tt.want, tt.wantErr)
			}
		})
	}
}
