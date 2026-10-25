package middleware

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

func testTokens() *security.TokenIssuer {
	return security.NewTokenIssuer(&config.Config{JWT: config.JWT{
		Secret: strings.Repeat("s", 32), Issuer: "test", Audience: "test", AccessTTL: 15 * time.Minute,
	}}, clock.System{})
}

func newApp() *fiber.App {
	return fiber.New(fiber.Config{ErrorHandler: response.ErrorHandler(slog.New(slog.NewTextHandler(io.Discard, nil)))})
}

// send runs req and returns the status and the problem code, if any.
func send(t *testing.T, app *fiber.App, req *http.Request) (*http.Response, string) {
	t.Helper()
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	var body struct {
		Code string `json:"code"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&body)
	return resp, body.Code
}

func TestAuthRejects(t *testing.T) {
	// Arrange
	tokens := testTokens()
	app := newApp()
	app.Get("/me", Auth(tokens), func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusNoContent) })
	tests := []struct {
		name   string
		header string
	}{
		{"no header", ""},
		{"no scheme", "abc"},
		{"basic scheme", "Basic dXNlcjpwYXNz"},
		{"empty token", "Bearer "},
		{"invalid token", "Bearer not.a.jwt"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req := httptest.NewRequest(http.MethodGet, "/me", nil)
			if tt.header != "" {
				req.Header.Set(fiber.HeaderAuthorization, tt.header)
			}

			// Act
			resp, code := send(t, app, req)

			// Assert
			if resp.StatusCode != 401 || code != "unauthorized" {
				t.Errorf("status %d code %q, want 401 unauthorized", resp.StatusCode, code)
			}
		})
	}
}

func TestAuthStoresIDs(t *testing.T) {
	// Arrange
	tokens := testTokens()
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	token, _, err := tokens.Issue(userID, sessionID)
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	var gotUser, gotSession uuid.UUID
	app := newApp()
	app.Get("/me", Auth(tokens), func(c fiber.Ctx) error {
		gotUser, gotSession = UserID(c), SessionID(c)
		return c.SendStatus(fiber.StatusNoContent)
	})
	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	req.Header.Set(fiber.HeaderAuthorization, "bearer "+token)

	// Act
	resp, _ := send(t, app, req)

	// Assert
	if resp.StatusCode != 204 {
		t.Fatalf("status %d, want 204", resp.StatusCode)
	}
	if gotUser != userID || gotSession != sessionID {
		t.Errorf("got %s/%s, want %s/%s", gotUser, gotSession, userID, sessionID)
	}
}

func TestRateLimit(t *testing.T) {
	// Arrange
	app := newApp()
	app.Post("/sign-in", RateLimit(2, time.Minute), func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusNoContent) })
	for range 2 {
		if resp, _ := send(t, app, httptest.NewRequest(http.MethodPost, "/sign-in", nil)); resp.StatusCode != 204 {
			t.Fatalf("status %d before the limit, want 204", resp.StatusCode)
		}
	}

	// Act
	resp, code := send(t, app, httptest.NewRequest(http.MethodPost, "/sign-in", nil))

	// Assert
	if resp.StatusCode != 429 || code != "rate_limit_exceeded" {
		t.Errorf("status %d code %q, want 429 rate_limit_exceeded", resp.StatusCode, code)
	}
	if resp.Header.Get(fiber.HeaderRetryAfter) == "" {
		t.Error("no Retry-After header")
	}
}
