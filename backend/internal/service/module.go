package service

import "go.uber.org/fx"

// Module provides every service.
var Module = fx.Module("service", fx.Provide(NewAuthService, NewPINService, NewProfileService))
