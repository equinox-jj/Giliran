package firebase

import (
	"context"

	fb "firebase.google.com/go/v4"
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

func newApp(cfg *config.Config) (*fb.App, error) {
	return NewApp(context.Background(), cfg.Firebase)
}

func newVerifier(app *fb.App) (*Verifier, error) {
	return NewVerifier(context.Background(), app)
}

// Module provides the API's AuthVerifier. The invoke builds it at startup,
// so a missing credentials file stops the API before it serves anything.
var Module = fx.Module("firebase",
	fx.Provide(
		newApp,
		newVerifier,
		func(v *Verifier) AuthVerifier { return v },
	),
	fx.Invoke(func(AuthVerifier) {}),
)

// WorkerModule provides the worker's Sender (FCM) and UserDeleter, built at
// startup like Module.
var WorkerModule = fx.Module("firebase",
	fx.Provide(
		newApp,
		newVerifier,
		func(v *Verifier) UserDeleter { return v },
		func(app *fb.App) (Sender, error) { return NewMessenger(context.Background(), app) },
	),
	fx.Invoke(func(Sender, UserDeleter) {}),
)
