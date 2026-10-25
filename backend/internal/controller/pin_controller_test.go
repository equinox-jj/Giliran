package controller

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

// fakePIN records its inputs and returns err.
type fakePIN struct {
	err error

	called     string
	gotUser    uuid.UUID
	gotSession uuid.UUID
	gotPINs    []string
	gotIDToken string
}

func (f *fakePIN) Set(_ context.Context, userID uuid.UUID, pin string) error {
	f.called, f.gotUser, f.gotPINs = "set", userID, []string{pin}
	return f.err
}

func (f *fakePIN) Verify(_ context.Context, userID uuid.UUID, pin string) error {
	f.called, f.gotUser, f.gotPINs = "verify", userID, []string{pin}
	return f.err
}

func (f *fakePIN) Change(_ context.Context, userID uuid.UUID, currentPIN, newPIN string) error {
	f.called, f.gotUser, f.gotPINs = "change", userID, []string{currentPIN, newPIN}
	return f.err
}

func (f *fakePIN) Reset(_ context.Context, userID, sessionID uuid.UUID, idToken, newPIN string) error {
	f.called, f.gotUser, f.gotSession, f.gotIDToken, f.gotPINs = "reset", userID, sessionID, idToken, []string{newPIN}
	return f.err
}

// newPINApp mounts the PIN routes as routes.Register does, minus rate limits.
func newPINApp(pin PINService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &PINController{pin: pin}
	auth := middleware.Auth(testTokens)
	app.Post("/api/v1/auth/pin", auth, h.Set)
	app.Put("/api/v1/auth/pin", auth, h.Change)
	app.Post("/api/v1/auth/pin/verify", auth, h.Verify)
	app.Post("/api/v1/auth/pin/reset", auth, h.Reset)
	return app
}

// authed builds a JSON request carrying a valid access token.
func authed(t *testing.T, method, path, body string) (*http.Request, uuid.UUID, uuid.UUID) {
	t.Helper()
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	token, _, err := testTokens.Issue(userID, sessionID)
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	req := jsonRequest(path, body)
	req.Method = method
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
	return req, userID, sessionID
}

func TestPINRoutes(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		method     string
		path       string
		body       string
		wantCalled string
		wantPINs   []string
	}{
		{"set", http.MethodPost, "/api/v1/auth/pin", `{"pin":"135792","pin_confirmation":"135792"}`, "set", []string{"135792"}},
		{"change", http.MethodPut, "/api/v1/auth/pin", `{"current_pin":"135792","new_pin":"246813","new_pin_confirmation":"246813"}`, "change", []string{"135792", "246813"}},
		{"verify", http.MethodPost, "/api/v1/auth/pin/verify", `{"pin":"135792"}`, "verify", []string{"135792"}},
		{"reset", http.MethodPost, "/api/v1/auth/pin/reset", `{"firebase_id_token":"fb","new_pin":"246813","new_pin_confirmation":"246813"}`, "reset", []string{"246813"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			fake := &fakePIN{}
			req, userID, _ := authed(t, tt.method, tt.path, tt.body)

			// Act
			resp, _ := call(t, newPINApp(fake), req)

			// Assert
			if resp.StatusCode != 204 {
				t.Fatalf("status %d, want 204", resp.StatusCode)
			}
			if fake.called != tt.wantCalled || fake.gotUser != userID || len(fake.gotPINs) != len(tt.wantPINs) {
				t.Fatalf("service got %s for %s with %v", fake.called, fake.gotUser, fake.gotPINs)
			}
			for i, pin := range tt.wantPINs {
				if fake.gotPINs[i] != pin {
					t.Errorf("pin %d = %q, want %q", i, fake.gotPINs[i], pin)
				}
			}
		})
	}
}

func TestPINResetPassesSession(t *testing.T) {
	// Arrange
	fake := &fakePIN{}
	req, _, sessionID := authed(t, http.MethodPost, "/api/v1/auth/pin/reset",
		`{"firebase_id_token":"fb","new_pin":"246813","new_pin_confirmation":"246813"}`)

	// Act
	call(t, newPINApp(fake), req)

	// Assert
	if fake.gotSession != sessionID || fake.gotIDToken != "fb" {
		t.Errorf("service got session %s token %q, want %s fb", fake.gotSession, fake.gotIDToken, sessionID)
	}
}

func TestPINErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		method     string
		path       string
		body       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"set mismatch", http.MethodPost, "/api/v1/auth/pin", `{"pin":"135792","pin_confirmation":"135793"}`, nil, 422, "validation_error"},
		{"set twice", http.MethodPost, "/api/v1/auth/pin", `{"pin":"135792","pin_confirmation":"135792"}`, model.ErrPINAlreadySet, 409, "pin_already_set"},
		{"change wrong pin", http.MethodPut, "/api/v1/auth/pin", `{"current_pin":"000001","new_pin":"246813","new_pin_confirmation":"246813"}`, model.ErrPINInvalid, 401, "pin_invalid"},
		{"change missing fields", http.MethodPut, "/api/v1/auth/pin", `{}`, nil, 422, "validation_error"},
		{"verify not set", http.MethodPost, "/api/v1/auth/pin/verify", `{"pin":"135792"}`, model.ErrPINNotSet, 409, "pin_not_set"},
		{"verify locked", http.MethodPost, "/api/v1/auth/pin/verify", `{"pin":"135792"}`, model.ErrPINLocked.WithRetryAfter(15 * time.Minute), 423, "pin_locked"},
		{"reset foreign otp", http.MethodPost, "/api/v1/auth/pin/reset", `{"firebase_id_token":"fb","new_pin":"246813","new_pin_confirmation":"246813"}`, model.ErrOTPInvalid, 401, "otp_invalid"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req, _, _ := authed(t, tt.method, tt.path, tt.body)

			// Act
			resp, body := call(t, newPINApp(&fakePIN{err: tt.serviceErr}), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestPINLockedSendsRetryAfter(t *testing.T) {
	// Arrange
	req, _, _ := authed(t, http.MethodPost, "/api/v1/auth/pin/verify", `{"pin":"135792"}`)
	app := newPINApp(&fakePIN{err: model.ErrPINLocked.WithRetryAfter(15 * time.Minute)})

	// Act
	resp, _ := call(t, app, req)

	// Assert
	if got := resp.Header.Get(fiber.HeaderRetryAfter); got != "900" {
		t.Errorf("Retry-After %q, want 900", got)
	}
}

func TestPINRequiresToken(t *testing.T) {
	// Arrange
	req := jsonRequest("/api/v1/auth/pin/verify", `{"pin":"135792"}`)

	// Act
	resp, body := call(t, newPINApp(&fakePIN{}), req)

	// Assert
	if resp.StatusCode != 401 || body["code"] != "unauthorized" {
		t.Errorf("status %d code %v, want 401 unauthorized", resp.StatusCode, body["code"])
	}
}
