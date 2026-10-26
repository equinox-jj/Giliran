package jobs

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"
)

// Migrate creates or upgrades River's own tables (river_job and friends),
// which db/migrations leaves out, and returns the versions it applied.
func Migrate(ctx context.Context, pool *pgxpool.Pool) ([]int, error) {
	m, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return nil, fmt.Errorf("river migrator: %w", err)
	}
	res, err := m.Migrate(ctx, rivermigrate.DirectionUp, nil)
	if err != nil {
		return nil, fmt.Errorf("river migrate: %w", err)
	}
	versions := make([]int, len(res.Versions))
	for i, v := range res.Versions {
		versions[i] = v.Version
	}
	return versions, nil
}
