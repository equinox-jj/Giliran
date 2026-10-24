package routes

import "go.uber.org/fx"

// Module registers the routes on the *fiber.App.
var Module = fx.Module("routes", fx.Invoke(Register))
