// Package controller holds the HTTP handlers. Each controller parses and
// validates a request, calls one service, and writes the reply through
// pkg/response; business rules live in internal/service.
package controller

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"
)

// Module provides every HTTP controller.
var Module = fx.Module("controller", fx.Provide(
	func(pool *pgxpool.Pool) *HealthController { return NewHealthController(pool) },
	NewAuthController, NewOTPController, NewPINController, NewMeController,
	NewGroupController, NewMemberController, NewPeriodController, NewPaymentController,
	NewDrawController, NewPayoutController, NewTransparencyController, NewReminderController,
	NewIdempotency,
))
