package jobs

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

// Enqueuer inserts jobs for cmd/worker to run. It wraps an insert-only
// River client, which works no jobs itself.
type Enqueuer struct {
	client *river.Client[pgx.Tx]
}

func NewEnqueuer(pool *pgxpool.Pool, log *slog.Logger) (*Enqueuer, error) {
	client, err := river.NewClient(riverpgxv5.New(pool), &river.Config{Logger: log})
	if err != nil {
		return nil, fmt.Errorf("river insert client: %w", err)
	}
	return &Enqueuer{client: client}, nil
}

// Enqueue inserts jobs. Inside repository.TxManager.WithTx they join the
// transaction, so they run only if the write that enqueued them commits.
func (e *Enqueuer) Enqueue(ctx context.Context, jobs ...river.InsertManyParams) error {
	if len(jobs) == 0 {
		return nil
	}
	var err error
	if tx, ok := repository.Tx(ctx); ok {
		_, err = e.client.InsertManyTx(ctx, tx, jobs)
	} else {
		_, err = e.client.InsertMany(ctx, jobs)
	}
	if err != nil {
		return fmt.Errorf("enqueue %s: %w", jobs[0].Args.Kind(), err)
	}
	return nil
}
