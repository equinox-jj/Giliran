package email

import (
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Module provides the worker's Sender. Building it does not contact the
// server, but a missing SMTP_HOST stops the worker at startup.
var Module = fx.Module("email",
	fx.Provide(func(cfg *config.Config) (Sender, error) {
		return NewSMTP(cfg.SMTP)
	}),
)
