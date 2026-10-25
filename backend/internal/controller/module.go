package controller

import "go.uber.org/fx"

// Module provides every HTTP controller.
var Module = fx.Module("controller", fx.Provide(NewHealthController, NewAuthController, NewPINController))
