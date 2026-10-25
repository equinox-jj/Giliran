package security

import "go.uber.org/fx"

// Module provides the PINHasher and the TokenIssuer.
var Module = fx.Module("security", fx.Provide(NewPINHasher, NewTokenIssuer))
