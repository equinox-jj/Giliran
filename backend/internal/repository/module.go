package repository

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"
)

// Module provides the connection pool and the TxManager. The invoke builds
// the pool even before anything depends on it, so startup pings the database
// and fails fast when it is unreachable.
var Module = fx.Module("repository",
	fx.Provide(
		newPool, NewTxManager, NewUserRepository, NewSessionRepository,
		NewGroupRepository, NewMemberRepository, NewLeaveRequestRepository,
		NewOwnershipTransferRepository, NewActivityRepository, NewPeriodRepository,
		NewPaymentRepository, NewIdempotencyRepository,
	),
	fx.Invoke(func(*pgxpool.Pool) {}),
)
