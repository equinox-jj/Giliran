// Command api runs the Giliran HTTP API.
package main

import (
	"log/slog"

	"go.uber.org/fx"
	"go.uber.org/fx/fxevent"

	"github.com/equinox-jj/Giliran/backend/internal/controller"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/routes"
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
	return fx.Options(
		config.Module,
		clock.Module,
		logger.Module,
		repository.Module,
		security.Module,
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
