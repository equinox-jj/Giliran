// Command worker runs Giliran's River background jobs: sign-in code emails,
// push notifications, daily reminders, missed-payment alerts,
// ownership-transfer and code expiry, cleanup and account purges.
//
//	worker           run the jobs until SIGINT or SIGTERM
//	worker migrate   create or upgrade River's tables, then exit
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"go.uber.org/fx"
	"go.uber.org/fx/fxevent"

	"github.com/equinox-jj/Giliran/backend/internal/clients/email"
	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/logger"
)

func main() {
	if len(os.Args) > 1 {
		if os.Args[1] != "migrate" {
			fmt.Fprintf(os.Stderr, "unknown command %q; usage: worker [migrate]\n", os.Args[1])
			os.Exit(2)
		}
		if err := migrate(context.Background()); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	fx.New(options()).Run()
}

// options is the whole dependency graph, shared with the wiring test.
func options() fx.Option {
	return fx.Options(
		config.Module,
		clock.Module,
		logger.Module,
		repository.Module,
		firebase.WorkerModule,
		email.Module,
		storage.Module,
		jobs.Module,
		jobs.WorkerModule,
		fx.WithLogger(func(log *slog.Logger) fxevent.Logger {
			l := &fxevent.SlogLogger{Logger: log}
			l.UseLogLevel(slog.LevelDebug) // Fx's own provide/invoke chatter
			return l
		}),
	)
}

// migrate brings River's tables up to date. Compose runs it before the API
// and the worker start, so the API never enqueues into missing tables.
func migrate(ctx context.Context) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	log := logger.New(os.Stdout, cfg.Log, cfg.App)
	pool, err := repository.NewPool(ctx, cfg.Database)
	if err != nil {
		return err
	}
	defer pool.Close()
	versions, err := jobs.Migrate(ctx, pool)
	if err != nil {
		return err
	}
	log.Info("river migrated", "applied", versions)
	return nil
}
