// Package routes maps URLs to controllers. Everything lives under /api/v1,
// except the public draw verification page at /v/{code}.
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

	App      *fiber.App
	Config   *config.Config
	Tokens   *security.TokenIssuer
	Health   *controller.HealthController
	Auth     *controller.AuthController
	PIN      *controller.PINController
	Me       *controller.MeController
	Groups   *controller.GroupController
	Members  *controller.MemberController
	Periods  *controller.PeriodController
	Payments *controller.PaymentController
	Draws    *controller.DrawController
	Payouts  *controller.PayoutController
	// Transparency serves the activity log and obligations.
	Transparency *controller.TransparencyController
	Reminders    *controller.ReminderController
	// Idempotency guards the writes that need an Idempotency-Key.
	Idempotency *controller.Idempotency
}

// Register adds every route to p.App.
func Register(p Params) {
	v1 := p.App.Group("/api/v1")
	v1.Get("/health", p.Health.Get)

	requireAuth := middleware.Auth(p.Tokens)
	rl := p.Config.RateLimit
	// Every write has a limiter (routes_test.go walks the table to check).
	// Per-user limits run after requireAuth; one handler shares its counters
	// across every route it is used on.
	writeLimit := middleware.RateLimitByUser(rl.WriteMax, rl.WriteWindow)

	// Handlers run in order, so middleware goes before the controller.
	auth := v1.Group("/auth")
	auth.Post("/sign-in", middleware.RateLimit(rl.OTPMax, rl.OTPWindow), p.Auth.SignIn)
	// Every device refreshes about once per access-token lifetime, and a
	// household shares one IP, so refresh gets the looser write limit.
	auth.Post("/refresh", middleware.RateLimit(rl.WriteMax, rl.WriteWindow), p.Auth.Refresh)
	auth.Post("/logout", requireAuth, writeLimit, p.Auth.Logout)

	// One per-user budget shared by every PIN check, on top of the lockout.
	pinLimit := middleware.RateLimitByUser(rl.PINMax, rl.PINWindow)
	auth.Post("/pin", requireAuth, pinLimit, p.PIN.Set)
	auth.Put("/pin", requireAuth, pinLimit, p.PIN.Change)
	auth.Post("/pin/verify", requireAuth, pinLimit, p.PIN.Verify)
	auth.Post("/pin/reset", requireAuth, middleware.RateLimitByUser(rl.OTPMax, rl.OTPWindow), p.PIN.Reset)
	auth.Put("/phone", requireAuth, middleware.RateLimitByUser(rl.OTPMax, rl.OTPWindow), p.Auth.ChangePhone)

	me := v1.Group("/me", requireAuth)
	me.Get("", p.Me.Get)
	me.Patch("", writeLimit, p.Me.Update)
	me.Put("/avatar", writeLimit, p.Me.UploadAvatar)
	me.Delete("/avatar", writeLimit, p.Me.DeleteAvatar)
	me.Get("/settings", p.Me.GetSettings)
	me.Patch("/settings", writeLimit, p.Me.UpdateSettings)
	me.Put("/push-token", writeLimit, p.Me.SetPushToken)
	me.Get("/sessions", p.Me.ListSessions)
	me.Delete("/sessions/:session_id", writeLimit, p.Me.RevokeSession)
	me.Get("/groups", p.Groups.ListMine)
	me.Post("/deletion", pinLimit, p.Me.DeleteAccount)

	v1.Post("/groups", requireAuth, writeLimit, p.Groups.Create)
	g := v1.Group("/groups/:group_id", requireAuth)
	g.Get("", p.Groups.Get)
	g.Patch("", writeLimit, p.Groups.Update)
	g.Put("/payment-info", writeLimit, p.Groups.SetPaymentInfo)
	g.Put("/payment-info/qris", writeLimit, p.Groups.UploadQRIS)
	g.Delete("/payment-info/qris", writeLimit, p.Groups.DeleteQRIS)
	g.Put("/fixed-order", writeLimit, p.Groups.SetFixedOrder)
	g.Post("/start", writeLimit, p.Groups.Start)
	g.Post("/close", writeLimit, p.Groups.Close)
	g.Post("/invite-code/reset", writeLimit, p.Groups.ResetInvite)

	g.Get("/members", p.Members.List)
	g.Post("/guests", writeLimit, p.Members.AddGuest)
	g.Get("/members/:member_id", p.Members.Get)
	g.Patch("/members/:member_id", writeLimit, p.Members.UpdateGuest)
	g.Delete("/members/:member_id", writeLimit, p.Members.Remove)
	g.Post("/members/:member_id/claim-link", writeLimit, p.Members.CreateClaimLink)
	g.Get("/leave-requests", p.Members.ListLeaveRequests)
	g.Post("/leave-requests", writeLimit, p.Members.RequestLeave)
	g.Post("/leave-requests/:request_id/approve", writeLimit, p.Members.ApproveLeave)
	g.Post("/leave-requests/:request_id/reject", writeLimit, p.Members.RejectLeave)
	g.Post("/ownership-transfers", writeLimit, p.Members.OfferOwnership)
	g.Post("/ownership-transfers/:transfer_id/accept", writeLimit, p.Members.AcceptOwnership)
	g.Post("/ownership-transfers/:transfer_id/decline", writeLimit, p.Members.DeclineOwnership)

	g.Get("/periods", p.Periods.List)
	g.Get("/periods/:period_id", p.Periods.Get)
	g.Get("/periods/:period_id/payments", p.Payments.Board)
	g.Get("/payments/:payment_id", p.Payments.Get)
	idem := p.Idempotency.Handle
	g.Post("/payments/:payment_id/proofs", writeLimit, idem, p.Payments.UploadProof)
	g.Post("/payments/:payment_id/approve", writeLimit, idem, p.Payments.Approve)
	g.Post("/payments/:payment_id/reject", writeLimit, idem, p.Payments.Reject)
	g.Post("/payments/:payment_id/mark-paid", writeLimit, idem, p.Payments.MarkPaid)
	g.Get("/periods/:period_id/draw", p.Draws.Get)
	g.Post("/periods/:period_id/draw", writeLimit, idem, p.Draws.Run)
	g.Get("/periods/:period_id/payout", p.Payouts.Get)
	g.Post("/periods/:period_id/payout", writeLimit, idem, p.Payouts.Record)
	g.Post("/periods/:period_id/payout/confirm", writeLimit, idem, p.Payouts.Confirm)
	g.Post("/periods/:period_id/reminders", writeLimit, idem, p.Reminders.Send)
	g.Get("/periods/:period_id/recap", p.Reminders.Recap)
	g.Get("/activity", p.Transparency.Activity)
	g.Get("/obligations", p.Transparency.Obligations)

	// Invite codes and claim tokens are the secret in a link; a per-user
	// limit slows anyone guessing them.
	inviteLimit := middleware.RateLimitByUser(rl.PublicMax, rl.PublicWindow)
	v1.Get("/invites/:invite_code", requireAuth, inviteLimit, p.Members.PreviewInvite)
	v1.Post("/invites/:invite_code/join", requireAuth, inviteLimit, p.Members.Join)
	v1.Post("/claims/:claim_token", requireAuth, inviteLimit, p.Members.Claim)

	// Bukti Kocok links are public; a per-IP limit slows code guessing. The
	// HTML page lives outside /api/v1 at APP_PUBLIC_BASE_URL/v/{code}.
	publicLimit := middleware.RateLimit(rl.PublicMax, rl.PublicWindow)
	v1.Get("/public/draws/:verification_code", publicLimit, p.Draws.Public)
	p.App.Get("/v/:verification_code", publicLimit, p.Draws.Page)
}
