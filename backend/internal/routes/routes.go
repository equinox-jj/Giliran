// Package routes maps URLs to controllers. Everything lives under /api/v1.
package routes

import (
	"github.com/gofiber/fiber/v3"
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/internal/controller"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

// Params are the controllers and settings the routes need.
type Params struct {
	fx.In

	App    *fiber.App
	Config *config.Config
	Tokens *security.TokenIssuer
	Health *controller.HealthController
	Auth   *controller.AuthController
	PIN    *controller.PINController
	Me     *controller.MeController
}

// Register adds every route to p.App.
func Register(p Params) {
	v1 := p.App.Group("/api/v1")
	v1.Get("/health", p.Health.Get)

	requireAuth := middleware.Auth(p.Tokens)
	rl := p.Config.RateLimit

	// Handlers run in order, so middleware goes before the controller.
	auth := v1.Group("/auth")
	auth.Post("/sign-in", middleware.RateLimit(rl.OTPMax, rl.OTPWindow), p.Auth.SignIn)
	// Every device refreshes about once per access-token lifetime, and a
	// household shares one IP, so refresh gets the looser write limit.
	auth.Post("/refresh", middleware.RateLimit(rl.WriteMax, rl.WriteWindow), p.Auth.Refresh)
	auth.Post("/logout", requireAuth, p.Auth.Logout)

	// One per-user budget shared by every PIN check, on top of the lockout.
	pinLimit := middleware.RateLimitByUser(rl.PINMax, rl.PINWindow)
	auth.Post("/pin", requireAuth, pinLimit, p.PIN.Set)
	auth.Put("/pin", requireAuth, pinLimit, p.PIN.Change)
	auth.Post("/pin/verify", requireAuth, pinLimit, p.PIN.Verify)
	auth.Post("/pin/reset", requireAuth, middleware.RateLimitByUser(rl.OTPMax, rl.OTPWindow), p.PIN.Reset)
	auth.Put("/phone", requireAuth, middleware.RateLimitByUser(rl.OTPMax, rl.OTPWindow), p.Auth.ChangePhone)

	me := v1.Group("/me", requireAuth)
	writeLimit := middleware.RateLimitByUser(rl.WriteMax, rl.WriteWindow)
	me.Get("", p.Me.Get)
	me.Patch("", writeLimit, p.Me.Update)
	me.Get("/settings", p.Me.GetSettings)
	me.Patch("/settings", writeLimit, p.Me.UpdateSettings)
	me.Put("/push-token", writeLimit, p.Me.SetPushToken)
	me.Get("/sessions", p.Me.ListSessions)
	me.Delete("/sessions/:session_id", writeLimit, p.Me.RevokeSession)
}
