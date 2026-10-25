package repository

import (
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Repository errors. Services translate them into model errors; they never
// reach a client as they are.
var (
	// ErrNotFound means the row does not exist (or is soft-deleted).
	ErrNotFound = errors.New("repository: not found")
	// ErrDuplicate means a unique constraint rejected the write.
	ErrDuplicate = errors.New("repository: duplicate")
)

// pgUniqueViolation is SQLSTATE unique_violation.
const pgUniqueViolation = "23505"

// mapErr turns pgx's no-rows and unique-violation errors into ErrNotFound and
// ErrDuplicate, and passes every other error through.
func mapErr(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == pgUniqueViolation {
		return fmt.Errorf("%w: %s", ErrDuplicate, pgErr.ConstraintName)
	}
	return err
}
