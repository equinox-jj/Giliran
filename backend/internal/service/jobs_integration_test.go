//go:build integration

package service

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

func newTestEnqueuer(t *testing.T, pool *pgxpool.Pool) *jobs.Enqueuer {
	t.Helper()
	e, err := jobs.NewEnqueuer(pool, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("NewEnqueuer: %v", err)
	}
	return e
}

// queued returns the args of every committed job of kind, oldest first.
func queued[T any](t *testing.T, pool *pgxpool.Pool, kind string) []T {
	t.Helper()
	rows, err := pool.Query(context.Background(), "SELECT args FROM river_job WHERE kind = $1 ORDER BY id", kind)
	if err != nil {
		t.Fatalf("query river_job: %v", err)
	}
	defer rows.Close()
	var out []T
	for rows.Next() {
		var raw []byte
		if err := rows.Scan(&raw); err != nil {
			t.Fatalf("scan river_job: %v", err)
		}
		var a T
		if err := json.Unmarshal(raw, &a); err != nil {
			t.Fatalf("decode %s args: %v", kind, err)
		}
		out = append(out, a)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("river_job rows: %v", err)
	}
	return out
}

func queuedPushes(t *testing.T, pool *pgxpool.Pool) []jobs.PushArgs {
	t.Helper()
	return queued[jobs.PushArgs](t, pool, jobs.PushArgs{}.Kind())
}

func TestEnqueueJoinsTransaction(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		fail  error
		wantN int
	}{
		{"commit", nil, 1},
		{"rollback", errors.New("write failed"), 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			pool := integration.NewDB(t)
			tx := repository.NewTxManager(pool)
			e := newTestEnqueuer(t, pool)

			// Act
			_ = tx.WithTx(context.Background(), func(ctx context.Context) error {
				if err := e.Enqueue(ctx, jobs.Push(uuid.Must(uuid.NewV7()), notify.KindDrawCompleted, notify.Params{}, nil)); err != nil {
					t.Fatalf("Enqueue: %v", err)
				}
				return tt.fail
			})

			// Assert
			if n := len(queuedPushes(t, pool)); n != tt.wantN {
				t.Errorf("%d jobs after %s, want %d", n, tt.name, tt.wantN)
			}
		})
	}
}
