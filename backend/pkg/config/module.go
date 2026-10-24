package config

import "go.uber.org/fx"

// Module provides *Config, loaded once at startup.
var Module = fx.Module("config", fx.Provide(Load))
