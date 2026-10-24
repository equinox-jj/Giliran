// Package logger builds the app-wide slog.Logger from LOG_LEVEL and
// LOG_FORMAT.
package logger

import (
	"io"
	"log/slog"
	"os"

	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Module provides *slog.Logger and makes it the slog default.
var Module = fx.Module("logger", fx.Provide(func(cfg *config.Config) *slog.Logger {
	l := New(os.Stdout, cfg.Log, cfg.App)
	slog.SetDefault(l)
	return l
}))

// New returns a logger writing to w, text or JSON per cfg.Format, tagged with
// the app name and environment. config.Load has already validated cfg.
func New(w io.Writer, cfg config.Log, app config.App) *slog.Logger {
	var level slog.Level
	_ = level.UnmarshalText([]byte(cfg.Level))
	opts := &slog.HandlerOptions{Level: level}

	var h slog.Handler
	if cfg.Format == "json" {
		h = slog.NewJSONHandler(w, opts)
	} else {
		h = slog.NewTextHandler(w, opts)
	}
	return slog.New(h).With("app", app.Name, "env", app.Env)
}
