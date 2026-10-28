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

// WorkerModule provides the worker's Sender (FCM). The invoke builds it at
// startup, so a missing credentials file stops the worker before it runs
// any job.
var WorkerModule = fx.Module("firebase",
	fx.Provide(
		newApp,
		func(app *fb.App) (Sender, error) { return NewMessenger(context.Background(), app) },
	),
	fx.Invoke(func(Sender) {}),
)
