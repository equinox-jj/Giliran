// Command api runs the Giliran HTTP API.
package main

import (
	"log/slog"

	"go.uber.org/fx"
	"go.uber.org/fx/fxevent"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/controller"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/routes"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/logger"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

func main() {
	fx.New(options()).Run()
}

// options is the whole dependency graph, shared with the wiring test.
func options() fx.Option {
	return fx.Options(core(), firebase.Module, storage.Module)
}

// core is the graph without the external clients (Firebase and MinIO), so
// the authorization sweep can run the real routes with fakes in their place.
func core() fx.Option {
	return fx.Options(
		config.Module,
		clock.Module,
		logger.Module,
		repository.Module,
		security.Module,
		jobs.Module,
		service.Module,
		controller.Module,
		fx.Provide(newServer),
		routes.Module,
		fx.WithLogger(func(log *slog.Logger) fxevent.Logger {
			l := &fxevent.SlogLogger{Logger: log}
			l.UseLogLevel(slog.LevelDebug) // Fx's own provide/invoke chatter
			return l
		}),
	)
}
