package firebase

import (
	"context"

	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Module provides the AuthVerifier and UserDeleter, both backed by one
// Admin SDK client. The invoke builds it at startup, so a missing
// credentials file stops the API before it serves anything.
var Module = fx.Module("firebase",
	fx.Provide(
		func(cfg *config.Config) (*Verifier, error) {
			return NewVerifier(context.Background(), cfg.Firebase)
		},
		func(v *Verifier) AuthVerifier { return v },
		func(v *Verifier) UserDeleter { return v },
	),
	fx.Invoke(func(AuthVerifier) {}),
)
