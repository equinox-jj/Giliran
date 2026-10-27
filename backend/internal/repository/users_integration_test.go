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

// TestUsersEmailConstraints checks migration 000007: an active user needs a
// lowercase, verified email, and the phone is optional.
func TestUsersEmailConstraints(t *testing.T) {
	// Arrange
	t.Parallel()
	pool := integration.NewDB(t)
	tests := []struct {
		name      string
		email     *string
		verified  bool
		phone     *string
		deleted   bool
		wantCheck string // empty means the insert succeeds
	}{
		{"active with verified email", new("rina@example.com"), true, nil, false, ""},
		{"active with email and phone", new("budi@example.com"), true, new("+6281234567890"), false, ""},
		{"deleted without email", nil, false, nil, true, ""},
		{"active without email", nil, false, nil, false, "users_email_required_unless_deleted"},
		{"active with unverified email", new("sari@example.com"), false, nil, false, "users_email_required_unless_deleted"},
		{"uppercase email", new("Rina@Example.com"), true, nil, false, "users_email_check"},
		{"malformed email", new("rina.example.com"), true, nil, false, "users_email_check"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := pool.Exec(context.Background(),
				`INSERT INTO users (id, email, email_verified_at, phone, deleted_at)
				 VALUES ($1, $2, CASE WHEN $3 THEN now() END, $4, CASE WHEN $5 THEN now() END)`,
				uuid.Must(uuid.NewV7()), tt.email, tt.verified, tt.phone, tt.deleted)

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

// TestUsersEmailUniqueAmongActive checks that an email belongs to one active
// account, while deleted accounts and shared phones don't block anyone.
func TestUsersEmailUniqueAmongActive(t *testing.T) {
	// Arrange
	pool := integration.NewDB(t)
	ctx := context.Background()
	insert := `INSERT INTO users (id, email, email_verified_at, phone) VALUES ($1, $2, now(), $3)`
	if _, err := pool.Exec(ctx, insert, uuid.Must(uuid.NewV7()), "rina@example.com", "+6281234567890"); err != nil {
		t.Fatalf("first insert: %v", err)
	}
	if _, err := pool.Exec(ctx, insert, uuid.Must(uuid.NewV7()), "budi@example.com", "+6281234567890"); err != nil {
		t.Fatalf("shared phone: %v", err)
	}

	// Act
	_, err := pool.Exec(ctx, insert, uuid.Must(uuid.NewV7()), "rina@example.com", nil)

	// Assert
	if !errors.Is(mapErr(err), ErrDuplicate) {
		t.Fatalf("got %v, want ErrDuplicate", err)
	}
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.ConstraintName != "users_email_active_uq" {
		t.Errorf("constraint %v, want users_email_active_uq", err)
	}
}
