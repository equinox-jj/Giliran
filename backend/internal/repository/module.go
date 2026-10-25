package repository

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"
)

// Module provides the connection pool and the TxManager. The invoke builds
// the pool even before anything depends on it, so startup pings the database
// and fails fast when it is unreachable.
var Module = fx.Module("repository",
	fx.Provide(newPool, NewTxManager),
	fx.Invoke(func(*pgxpool.Pool) {}),
)
