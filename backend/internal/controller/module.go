package controller

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"
)

// Module provides every HTTP controller.
var Module = fx.Module("controller", fx.Provide(
	func(pool *pgxpool.Pool) *HealthController { return NewHealthController(pool) },
	NewAuthController, NewPINController, NewMeController,
	NewGroupController, NewMemberController, NewPeriodController, NewPaymentController,
	NewDrawController, NewPayoutController, NewTransparencyController, NewReminderController,
	NewIdempotency,
))
