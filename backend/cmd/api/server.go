package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"

	"github.com/gofiber/fiber/v3"
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// newFiberApp builds the app with the global middleware; routes are added
// afterwards by routes.Register.
func newFiberApp(cfg *config.Config, log *slog.Logger) *fiber.App {
	fc := fiber.Config{
		AppName:      cfg.App.Name,
		BodyLimit:    cfg.HTTP.BodyLimit,
		ReadTimeout:  cfg.HTTP.ReadTimeout,
		WriteTimeout: cfg.HTTP.WriteTimeout,
		IdleTimeout:  cfg.HTTP.IdleTimeout,
		ErrorHandler: response.ErrorHandler(log),
	}
	if len(cfg.HTTP.TrustedProxies) > 0 {
		fc.TrustProxy = true
		fc.TrustProxyConfig = fiber.TrustProxyConfig{Proxies: cfg.HTTP.TrustedProxies}
		fc.ProxyHeader = fiber.HeaderXForwardedFor
	}

	app := fiber.New(fc)
	app.Use(middleware.RequestID(), middleware.Recover(log))
	if len(cfg.HTTP.CORSAllowOrigins) > 0 {
		app.Use(middleware.CORS(cfg.HTTP.CORSAllowOrigins))
	}
	return app
}

// newServer provides the *fiber.App and ties it to the Fx lifecycle: listen
// on start, drain in-flight requests on stop.
func newServer(lc fx.Lifecycle, cfg *config.Config, log *slog.Logger) *fiber.App {
	app := newFiberApp(cfg, log)

	lc.Append(fx.Hook{
		OnStart: func(context.Context) error {
			// Bind here so a busy port fails startup instead of a goroutine.
			ln, err := net.Listen("tcp", cfg.HTTP.Addr())
			if err != nil {
				return fmt.Errorf("listen on %s: %w", cfg.HTTP.Addr(), err)
			}
			go func() {
				if err := app.Listener(ln, fiber.ListenConfig{DisableStartupMessage: true}); err != nil && !errors.Is(err, net.ErrClosed) {
					log.Error("http server stopped", "error", err)
				}
			}()
			log.Info("http server listening", "addr", ln.Addr().String())
			return nil
		},
		OnStop: func(ctx context.Context) error {
			ctx, cancel := context.WithTimeout(ctx, cfg.HTTP.ShutdownTimeout)
			defer cancel()
			log.Info("http server shutting down")
			return app.ShutdownWithContext(ctx)
		},
	})
	return app
}
