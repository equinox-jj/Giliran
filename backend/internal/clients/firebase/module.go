package firebase

import (
	"context"

	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Module provides the AuthVerifier. The invoke builds it at startup, so a
// missing credentials file stops the API before it serves anything.
var Module = fx.Module("firebase",
	fx.Provide(func(cfg *config.Config) (AuthVerifier, error) {
		return NewVerifier(context.Background(), cfg.Firebase)
	}),
	fx.Invoke(func(AuthVerifier) {}),
)
