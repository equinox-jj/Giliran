//go:build integration

package repository

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

// createUser inserts a user through whatever Queries(ctx) returns.
func createUser(ctx context.Context, m *TxManager) (uuid.UUID, error) {
	id := uuid.Must(uuid.NewV7())
	_, err := m.Queries(ctx).CreateUser(ctx, sqlc.CreateUserParams{ID: id, Email: id.String() + "@example.com", VerifiedAt: time.Now()})
	return id, err
}

// userExists reports whether id is visible outside any transaction.
func userExists(t *testing.T, m *TxManager, id uuid.UUID) bool {
	t.Helper()
	_, err := m.Queries(context.Background()).GetUserByID(context.Background(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		return false
	}
	if err != nil {
		t.Fatalf("GetUserByID: %v", err)
	}
	return true
}

func TestWithTxCommits(t *testing.T) {
	// Arrange
	t.Parallel()
	m := NewTxManager(integration.NewDB(t))
	var id uuid.UUID

	// Act
	err := m.WithTx(context.Background(), func(ctx context.Context) error {
		var err error
		id, err = createUser(ctx, m)
		return err
	})

	// Assert
	if err != nil {
		t.Fatalf("WithTx: %v", err)
	}
	if !userExists(t, m, id) {
		t.Error("user not visible after commit")
	}
}

func TestWithTxRollsBackOnError(t *testing.T) {
	// Arrange
	t.Parallel()
	m := NewTxManager(integration.NewDB(t))
	errBoom := errors.New("boom")
	var id uuid.UUID

	// Act
	err := m.WithTx(context.Background(), func(ctx context.Context) error {
		var err error
		if id, err = createUser(ctx, m); err != nil {
			return err
		}
		return errBoom
	})

	// Assert
	if !errors.Is(err, errBoom) {
		t.Fatalf("WithTx error = %v, want %v", err, errBoom)
	}
	if userExists(t, m, id) {
		t.Error("user visible after rollback")
	}
}

func TestWithTxRollsBackOnPanic(t *testing.T) {
	// Arrange
	t.Parallel()
	m := NewTxManager(integration.NewDB(t))
	var id uuid.UUID

	// Act
	recovered := func() (r any) {
		defer func() { r = recover() }()
		_ = m.WithTx(context.Background(), func(ctx context.Context) error {
			var err error
			if id, err = createUser(ctx, m); err != nil {
				t.Errorf("createUser: %v", err)
			}
			panic("boom")
		})
		return nil
	}()

	// Assert
	if recovered != "boom" {
		t.Fatalf("recovered %v, want the panic to propagate", recovered)
	}
	if userExists(t, m, id) {
		t.Error("user visible after panic")
	}
}

func TestWithTxNestedJoinsOuter(t *testing.T) {
	// Arrange
	t.Parallel()
	m := NewTxManager(integration.NewDB(t))
	errBoom := errors.New("boom")
	var id uuid.UUID
	var innerInTx bool

	// Act
	err := m.WithTx(context.Background(), func(ctx context.Context) error {
		if err := m.WithTx(ctx, func(ctx context.Context) error {
			innerInTx = InTx(ctx)
			var err error
			id, err = createUser(ctx, m)
			return err
		}); err != nil {
			return err
		}
		return errBoom
	})

	// Assert
	if !errors.Is(err, errBoom) {
		t.Fatalf("WithTx error = %v, want %v", err, errBoom)
	}
	if !innerInTx {
		t.Error("inner WithTx ran outside a transaction")
	}
	if userExists(t, m, id) {
		t.Error("inner write survived the outer rollback")
	}
}

func TestQueriesWithoutTxAutocommits(t *testing.T) {
	// Arrange
	t.Parallel()
	m := NewTxManager(integration.NewDB(t))

	// Act
	id, err := createUser(context.Background(), m)

	// Assert
	if err != nil {
		t.Fatalf("createUser: %v", err)
	}
	if !userExists(t, m, id) {
		t.Error("user not visible after a pool write")
	}
}
