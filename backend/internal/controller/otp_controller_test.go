package controller

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

// fakeOTP records its inputs and returns canned results.
type fakeOTP struct {
	challenge service.OTPChallenge
	result    service.OTPResult
	err       error

	called    string
	gotStart  service.OTPStart
	gotID     uuid.UUID
	gotVerify service.OTPVerify
	gotCaller *service.Caller
}

func (f *fakeOTP) Request(_ context.Context, in service.OTPStart) (service.OTPChallenge, error) {
	f.called, f.gotStart, f.gotCaller = "request", in, in.Caller
	return f.challenge, f.err
}

func (f *fakeOTP) Resend(_ context.Context, otpID uuid.UUID, caller *service.Caller) (service.OTPChallenge, error) {
	f.called, f.gotID, f.gotCaller = "resend", otpID, caller
	return f.challenge, f.err
}

func (f *fakeOTP) Verify(_ context.Context, otpID uuid.UUID, in service.OTPVerify, caller *service.Caller) (service.OTPResult, error) {
	f.called, f.gotID, f.gotVerify, f.gotCaller = "verify", otpID, in, caller
	return f.result, f.err
}

// newOTPApp mounts the email code routes as routes.Register does, minus
// rate limits.
func newOTPApp(otp OTPService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &OTPController{otp: otp}
	optional := middleware.OptionalAuth(testTokens)
	app.Post("/api/v1/auth/email/otp", optional, h.Request)
	app.Post("/api/v1/auth/email/otp/:otp_id/resend", optional, h.Resend)
	app.Post("/api/v1/auth/email/otp/:otp_id/verify", optional, h.Verify)
	return app
}

func testChallenge(purpose model.OTPPurpose) service.OTPChallenge {
	now := time.Now().UTC()
	return service.OTPChallenge{
		ID:                uuid.Must(uuid.NewV7()),
		Purpose:           purpose,
		EmailMasked:       "ri•••••@gmail.com",
		ExpiresAt:         now.Add(10 * time.Minute),
		ResendAvailableAt: now.Add(time.Minute),
		AttemptsRemaining: model.OTPMaxAttempts,
	}
}

const signInBody = `{"purpose":"sign_in","email":"rina.wulandari@gmail.com","device_name":"Samsung Galaxy A54","device_platform":"android","fcm_token":"fcm"}`

func TestOTPRequestSignIn(t *testing.T) {
	// Arrange
	fake := &fakeOTP{challenge: testChallenge(model.OTPPurposeSignIn)}
	req := jsonRequest("/api/v1/auth/email/otp", signInBody)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 202 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	in := fake.gotStart
	if in.Purpose != model.OTPPurposeSignIn || in.Email != "rina.wulandari@gmail.com" || in.Device.Name != "Samsung Galaxy A54" ||
		in.Device.Platform != model.DevicePlatformAndroid || in.Device.FCMToken == nil || *in.Device.FCMToken != "fcm" {
		t.Errorf("service got %+v", in)
	}
	if in.Caller != nil || in.PIN != nil || in.IP == nil {
		t.Errorf("caller %v, pin %v, ip %v; want anonymous, no PIN, an IP", in.Caller, in.PIN, in.IP)
	}
	data := body["data"].(map[string]any)
	if data["id"] != fake.challenge.ID.String() || data["code_length"] != float64(6) || data["attempts_remaining"] != float64(5) {
		t.Errorf("data %v", data)
	}
}

func TestOTPRequestChangeEmailPassesCaller(t *testing.T) {
	// Arrange
	fake := &fakeOTP{challenge: testChallenge(model.OTPPurposeChangeEmail)}
	req, userID, sessionID := authed(t, http.MethodPost, "/api/v1/auth/email/otp",
		`{"purpose":"change_email","email":"rina.baru@gmail.com","device_name":"d","device_platform":"ios","pin":"135792"}`)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 202 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	c := fake.gotCaller
	if c == nil || c.UserID != userID || c.SessionID != sessionID {
		t.Errorf("caller %+v, want %s/%s", c, userID, sessionID)
	}
	if fake.gotStart.PIN == nil || *fake.gotStart.PIN != "135792" {
		t.Errorf("pin %v, want 135792", fake.gotStart.PIN)
	}
}

func TestOTPRequestErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		body       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"missing fields", `{}`, nil, 422, "validation_error"},
		{"unknown purpose", strings.Replace(signInBody, "sign_in", "sign_up", 1), nil, 422, "validation_error"},
		{"bad email", strings.Replace(signInBody, "rina.wulandari@gmail.com", "rina", 1), nil, 422, "validation_error"},
		{"unknown platform", strings.Replace(signInBody, "android", "windows", 1), nil, 422, "validation_error"},
		{"change_email anonymous", signInBody, model.ErrUnauthorized, 401, "unauthorized"},
		{"email taken", signInBody, model.ErrEmailAlreadyRegistered, 409, "email_already_registered"},
		{"pin locked", signInBody, model.ErrPINLocked.WithRetryAfter(15 * time.Minute), 423, "pin_locked"},
		{"too many codes", signInBody, model.ErrRateLimitExceeded.WithRetryAfter(time.Hour), 429, "rate_limit_exceeded"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			fake := &fakeOTP{err: tt.serviceErr}

			// Act
			resp, body := call(t, newOTPApp(fake), jsonRequest("/api/v1/auth/email/otp", tt.body))

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestOTPRequestInvalidTokenIsUnauthorized(t *testing.T) {
	// Arrange
	fake := &fakeOTP{}
	req := jsonRequest("/api/v1/auth/email/otp", signInBody)
	req.Header.Set(fiber.HeaderAuthorization, "Bearer expired.or.forged")

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 401 || body["code"] != "unauthorized" || fake.called != "" {
		t.Errorf("status %d code %v, service called %q", resp.StatusCode, body["code"], fake.called)
	}
}

func TestOTPResend(t *testing.T) {
	// Arrange
	fake := &fakeOTP{challenge: testChallenge(model.OTPPurposeSignIn)}
	id := fake.challenge.ID
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/email/otp/"+id.String()+"/resend", nil)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 202 || fake.called != "resend" || fake.gotID != id || fake.gotCaller != nil {
		t.Fatalf("status %d, service got %s %s caller %v", resp.StatusCode, fake.called, fake.gotID, fake.gotCaller)
	}
	if data := body["data"].(map[string]any); data["id"] != id.String() {
		t.Errorf("data %v", data)
	}
}

func TestOTPResendErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		id         string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"unknown request", uuid.Must(uuid.NewV7()).String(), model.ErrOTPNotFound, 404, "otp_not_found"},
		{"used", uuid.Must(uuid.NewV7()).String(), model.ErrOTPAlreadyUsed, 409, "otp_already_used"},
		{"expired", uuid.Must(uuid.NewV7()).String(), model.ErrOTPExpired, 410, "otp_expired"},
		{"too soon", uuid.Must(uuid.NewV7()).String(), model.ErrRateLimitExceeded.WithRetryAfter(time.Minute), 429, "rate_limit_exceeded"},
		{"no resends left", uuid.Must(uuid.NewV7()).String(), model.ErrOTPTooManyAttempts, 429, "otp_too_many_attempts"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/email/otp/"+tt.id+"/resend", nil)

			// Act
			resp, body := call(t, newOTPApp(&fakeOTP{err: tt.serviceErr}), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestOTPResendMalformedID(t *testing.T) {
	// Arrange
	fake := &fakeOTP{}
	app := newOTPApp(fake)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/email/otp/not-a-uuid/resend", nil)

	// Act
	resp, err := app.Test(req)

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != 404 || fake.called != "" {
		t.Errorf("status %d, service called %q; want 404 without a call", resp.StatusCode, fake.called)
	}
}

func TestOTPVerifySignIn(t *testing.T) {
	// Arrange
	user := model.User{ID: uuid.Must(uuid.NewV7()), Email: &testEmail, CreatedAt: time.Now()}
	fake := &fakeOTP{result: service.OTPResult{
		Purpose: model.OTPPurposeSignIn,
		Auth: &service.SignInResult{
			Profile:   service.Profile{User: user},
			Tokens:    service.TokenPair{AccessToken: "access", RefreshToken: "refresh", ExpiresIn: 15 * time.Minute},
			IsNewUser: true,
		},
	}}
	id := uuid.Must(uuid.NewV7())
	req := jsonRequest("/api/v1/auth/email/otp/"+id.String()+"/verify", `{"code":"482913","pin":"135792"}`)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	v := fake.gotVerify
	if fake.gotID != id || v.Code != "482913" || v.PIN == nil || *v.PIN != "135792" || v.NewPIN != nil || fake.gotCaller != nil {
		t.Errorf("service got %s %+v caller %v", fake.gotID, v, fake.gotCaller)
	}
	data := body["data"].(map[string]any)
	auth, _ := data["auth"].(map[string]any)
	if data["purpose"] != "sign_in" || data["user"] != nil || auth == nil || auth["is_new_user"] != true {
		t.Fatalf("data %v", data)
	}
	if tokens := auth["tokens"].(map[string]any); tokens["token_type"] != "Bearer" || tokens["expires_in"] != float64(900) {
		t.Errorf("tokens %v", tokens)
	}
}

func TestOTPVerifyResetPIN(t *testing.T) {
	// Arrange
	user := model.User{ID: uuid.Must(uuid.NewV7()), Email: &testEmail, PINHash: ptr("hash"), CreatedAt: time.Now()}
	fake := &fakeOTP{result: service.OTPResult{
		Purpose: model.OTPPurposeResetPIN,
		Auth:    &service.SignInResult{Profile: service.Profile{User: user}, Tokens: service.TokenPair{AccessToken: "a", RefreshToken: "r", ExpiresIn: time.Minute}},
	}}
	req := jsonRequest("/api/v1/auth/email/otp/"+uuid.Must(uuid.NewV7()).String()+"/verify",
		`{"code":"482913","new_pin":"246813","new_pin_confirmation":"246813"}`)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	v := fake.gotVerify
	if v.NewPIN == nil || *v.NewPIN != "246813" || v.NewPINConfirmation == nil || *v.NewPINConfirmation != "246813" {
		t.Errorf("service got %+v", v)
	}
	if auth := body["data"].(map[string]any)["auth"].(map[string]any); auth["pin_set"] != true {
		t.Errorf("auth %v", auth)
	}
}

func TestOTPVerifyChangeEmail(t *testing.T) {
	// Arrange
	email := "rina.baru@gmail.com"
	fake := &fakeOTP{result: service.OTPResult{
		Purpose: model.OTPPurposeChangeEmail,
		User:    &service.Profile{User: model.User{ID: uuid.Must(uuid.NewV7()), Email: &email, CreatedAt: time.Now()}},
	}}
	req, userID, sessionID := authed(t, http.MethodPost,
		"/api/v1/auth/email/otp/"+uuid.Must(uuid.NewV7()).String()+"/verify", `{"code":"482913"}`)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	if c := fake.gotCaller; c == nil || c.UserID != userID || c.SessionID != sessionID {
		t.Errorf("caller %+v, want %s/%s", c, userID, sessionID)
	}
	data := body["data"].(map[string]any)
	user, _ := data["user"].(map[string]any)
	if data["auth"] != nil || user == nil || user["email"] != email {
		t.Errorf("data %v", data)
	}
}

func TestOTPVerifyErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		body       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"missing code", `{}`, nil, 422, "validation_error"},
		{"short code", `{"code":"12345"}`, nil, 422, "validation_error"},
		{"signed code", `{"code":"+12345"}`, nil, 422, "validation_error"},
		{"pin required", `{"code":"482913"}`, model.ErrPINRequired, 422, "pin_required"},
		{"wrong pin", `{"code":"482913","pin":"000001"}`, model.ErrPINInvalid, 401, "pin_invalid"},
		{"unknown request", `{"code":"482913"}`, model.ErrOTPNotFound, 404, "otp_not_found"},
		{"used", `{"code":"482913"}`, model.ErrOTPAlreadyUsed, 409, "otp_already_used"},
		{"expired", `{"code":"482913"}`, model.ErrOTPExpired, 410, "otp_expired"},
		{"pin locked", `{"code":"482913","pin":"000001"}`, model.ErrPINLocked.WithRetryAfter(15 * time.Minute), 423, "pin_locked"},
		{"locked", `{"code":"482913"}`, model.ErrOTPTooManyAttempts, 429, "otp_too_many_attempts"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req := jsonRequest("/api/v1/auth/email/otp/"+uuid.Must(uuid.NewV7()).String()+"/verify", tt.body)

			// Act
			resp, body := call(t, newOTPApp(&fakeOTP{err: tt.serviceErr}), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestOTPVerifyWrongCodeReportsAttemptsRemaining(t *testing.T) {
	// Arrange
	fake := &fakeOTP{err: model.ErrOTPInvalid.WithExtensions(map[string]any{"attempts_remaining": 3})}
	req := jsonRequest("/api/v1/auth/email/otp/"+uuid.Must(uuid.NewV7()).String()+"/verify", `{"code":"000000"}`)

	// Act
	resp, body := call(t, newOTPApp(fake), req)

	// Assert
	if resp.StatusCode != 422 || body["code"] != "otp_invalid" || body["attempts_remaining"] != float64(3) {
		t.Errorf("status %d body %v, want 422 otp_invalid with attempts_remaining 3", resp.StatusCode, body)
	}
}
