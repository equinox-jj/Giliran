package storage

import (
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Module provides Storage backed by MinIO. Building the client does not
// contact the server, so MinIO being down does not stop the API starting.
var Module = fx.Module("storage",
	fx.Provide(func(cfg *config.Config) (Storage, error) {
		return NewMinIO(cfg.MinIO)
	}),
)
