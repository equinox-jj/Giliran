package routes

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/controller"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

// tightConfig allows one request per limiter per hour.
func tightConfig() *config.Config {
	return &config.Config{
		JWT: config.JWT{Secret: strings.Repeat("s", 32), Issuer: "giliran-test", Audience: "giliran-test", AccessTTL: 15 * time.Minute},
		RateLimit: config.RateLimit{
			OTPMax: 1, OTPWindow: time.Hour,
			PINMax: 1, PINWindow: time.Hour,
			WriteMax: 1, WriteWindow: time.Hour,
			PublicMax: 1, PublicWindow: time.Hour,
		},
	}
}

// newLimitedApp registers every route over controllers without services, so
// a request that gets past the middleware panics and is recovered as a 500.
func newLimitedApp(cfg *config.Config, tokens *security.TokenIssuer) *fiber.App {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	app := fiber.New(fiber.Config{ErrorHandler: response.ErrorHandler(log)})
	app.Use(middleware.RequestID(), middleware.Recover(log))
	Register(Params{
		App:          app,
		Config:       cfg,
		Tokens:       tokens,
		Health:       controller.NewHealthController(nil),
		Auth:         controller.NewAuthController(nil),
		PIN:          controller.NewPINController(nil),
		Me:           controller.NewMeController(nil, nil),
		Groups:       controller.NewGroupController(nil),
		Members:      controller.NewMemberController(nil, nil, nil),
		Periods:      controller.NewPeriodController(nil),
		Payments:     controller.NewPaymentController(nil),
		Draws:        controller.NewDrawController(nil),
		Payouts:      controller.NewPayoutController(nil),
		Transparency: controller.NewTransparencyController(nil),
		Reminders:    controller.NewReminderController(nil),
		Idempotency:  controller.NewIdempotency(nil),
	})
	return app
}

var pathParam = regexp.MustCompile(`:[a-z_]+`)

func TestEveryWriteRouteIsRateLimited(t *testing.T) {
	// Arrange
	cfg := tightConfig()
	tokens := security.NewTokenIssuer(cfg, clock.System{})
	token, _, err := tokens.Issue(uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7()))
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	var writes []fiber.Route
	for _, r := range newLimitedApp(cfg, tokens).GetRoutes(true) {
		switch r.Method {
		case http.MethodGet, http.MethodHead, http.MethodOptions:
			continue
		}
		writes = append(writes, r)
	}
	if len(writes) == 0 {
		t.Fatal("no write routes registered")
	}
	send := func(app *fiber.App, method, path string) *http.Response {
		req := httptest.NewRequest(method, path, nil)
		req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("app.Test: %v", err)
		}
		return resp
	}

	for _, r := range writes {
		t.Run(r.Method+" "+r.Path, func(t *testing.T) {
			// Each route gets fresh counters, since limiters are shared.
			app := newLimitedApp(cfg, tokens)
			path := pathParam.ReplaceAllString(r.Path, uuid.Must(uuid.NewV7()).String())
			send(app, r.Method, path)

			// Act
			resp := send(app, r.Method, path)

			// Assert
			var body map[string]any
			if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
				t.Fatalf("decode body: %v", err)
			}
			if resp.StatusCode != fiber.StatusTooManyRequests || body["code"] != "rate_limit_exceeded" {
				t.Errorf("second request: status %d code %v, want 429 rate_limit_exceeded (no limiter on this route?)", resp.StatusCode, body["code"])
			}
		})
	}
}
