//go:build integration

package repository

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/equinox-jj/Giliran/backend/test/integration"
)

// TestUsersPhoneRequiredUnlessDeleted checks migration 000002: only a deleted
// user may have no phone.
func TestUsersPhoneRequiredUnlessDeleted(t *testing.T) {
	// Arrange
	t.Parallel()
	pool := integration.NewDB(t)
	tests := []struct {
		name      string
		phone     *string
		deleted   bool
		wantCheck string // empty means the insert succeeds
	}{
		{"active with phone", new("+6281234567890"), false, ""},
		{"deleted with phone", new("+6281234567891"), true, ""},
		{"deleted without phone", nil, true, ""},
		{"active without phone", nil, false, "users_phone_required_unless_deleted"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := pool.Exec(context.Background(),
				`INSERT INTO users (id, phone, deleted_at)
				 VALUES ($1, $2, CASE WHEN $3 THEN now() END)`,
				uuid.Must(uuid.NewV7()), tt.phone, tt.deleted)

			// Assert
			if tt.wantCheck == "" {
				if err != nil {
					t.Errorf("insert: %v", err)
				}
				return
			}
			var pgErr *pgconn.PgError
			if !errors.As(err, &pgErr) || pgErr.Code != "23514" || pgErr.ConstraintName != tt.wantCheck {
				t.Errorf("got %v, want check violation on %s", err, tt.wantCheck)
			}
		})
	}
}
