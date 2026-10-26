// Package repository is the database layer. It wraps the sqlc-generated
// queries in repository/sqlc and maps their rows to internal/model types.
package repository

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// NewPool builds a connection pool from cfg. It does not connect yet; pgx
// dials lazily, so call Ping to check the database is reachable.
func NewPool(ctx context.Context, cfg config.Database) (*pgxpool.Pool, error) {
	pc, err := pgxpool.ParseConfig(cfg.URL)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	pc.MaxConns = cfg.MaxConns
	pc.MinConns = cfg.MinConns
	pc.MaxConnLifetime = cfg.MaxConnLifetime
	pc.MaxConnIdleTime = cfg.MaxConnIdleTime
	// Timestamps are stored and compared in UTC; business dates are DATE
	// columns and never depend on the session time zone.
	pc.ConnConfig.RuntimeParams["timezone"] = "UTC"

	pool, err := pgxpool.NewWithConfig(ctx, pc)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	return pool, nil
}

// newPool provides the pool to Fx: ping on start so a missing database fails
// startup, close on stop.
func newPool(lc fx.Lifecycle, cfg *config.Config, log *slog.Logger) (*pgxpool.Pool, error) {
	pool, err := NewPool(context.Background(), cfg.Database)
	if err != nil {
		return nil, err
	}
	lc.Append(fx.Hook{
		OnStart: func(ctx context.Context) error {
			if err := pool.Ping(ctx); err != nil {
				return fmt.Errorf("ping database: %w", err)
			}
			log.Info("database connected", "max_conns", cfg.Database.MaxConns)
			return nil
		},
		OnStop: func(context.Context) error {
			pool.Close()
			return nil
		},
	})
	return pool, nil
}

type txKey struct{}

// TxManager runs work in a transaction carried by the context, and hands
// repositories the queries bound to it.
type TxManager struct {
	pool    *pgxpool.Pool
	queries *sqlc.Queries
}

// NewTxManager returns a TxManager over pool.
func NewTxManager(pool *pgxpool.Pool) *TxManager {
	return &TxManager{pool: pool, queries: sqlc.New(pool)}
}

// WithTx runs fn in a transaction and commits if fn returns nil. It rolls
// back if fn returns an error or panics. If ctx already carries a
// transaction, fn joins it and the outermost WithTx decides the outcome, so
// services can call each other without nesting transactions.
func (m *TxManager) WithTx(ctx context.Context, fn func(ctx context.Context) error) error {
	if InTx(ctx) {
		return fn(ctx)
	}
	return pgx.BeginFunc(ctx, m.pool, func(tx pgx.Tx) error {
		return fn(context.WithValue(ctx, txKey{}, tx))
	})
}

// Queries returns the queries bound to the transaction in ctx, or to the
// pool when there is none.
func (m *TxManager) Queries(ctx context.Context) *sqlc.Queries {
	if tx, ok := ctx.Value(txKey{}).(pgx.Tx); ok {
		return m.queries.WithTx(tx)
	}
	return m.queries
}

// InTx reports whether ctx carries a transaction started by WithTx. Writes
// that must share a transaction, such as activity log entries (BR-09), check
// it.
func InTx(ctx context.Context) bool {
	_, ok := ctx.Value(txKey{}).(pgx.Tx)
	return ok
}

// Tx returns the transaction ctx carries, if any. River inserts jobs with it,
// so a job commits or rolls back with the write that enqueued it.
func Tx(ctx context.Context) (pgx.Tx, bool) {
	tx, ok := ctx.Value(txKey{}).(pgx.Tx)
	return tx, ok
}
