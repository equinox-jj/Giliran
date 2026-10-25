package controller

import (
	"context"
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

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
	"github.com/equinox-jj/Giliran/backend/test/contract"
)

// fakeAuth records its inputs and returns canned results.
type fakeAuth struct {
	signInResult service.SignInResult
	pair         service.TokenPair
	err          error

	gotIDToken string
	gotDevice  service.Device
	gotRefresh string
	gotUser    uuid.UUID
	gotSession uuid.UUID
}

func (f *fakeAuth) SignIn(_ context.Context, idToken string, device service.Device) (service.SignInResult, error) {
	f.gotIDToken, f.gotDevice = idToken, device
	return f.signInResult, f.err
}

func (f *fakeAuth) Refresh(_ context.Context, refreshToken string) (service.TokenPair, error) {
	f.gotRefresh = refreshToken
	return f.pair, f.err
}

func (f *fakeAuth) Logout(_ context.Context, userID, sessionID uuid.UUID) error {
	f.gotUser, f.gotSession = userID, sessionID
	return f.err
}

var testTokens = security.NewTokenIssuer(&config.Config{JWT: config.JWT{
	Secret: strings.Repeat("s", 32), Issuer: "test", Audience: "test", AccessTTL: 15 * time.Minute,
}}, clock.System{})

// newAuthApp mounts the auth routes as routes.Register does, minus rate
// limits, with the production error handler and validator.
func newAuthApp(auth AuthService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(slog.New(slog.NewTextHandler(io.Discard, nil))),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &AuthController{auth: auth}
	app.Post("/api/v1/auth/sign-in", h.SignIn)
	app.Post("/api/v1/auth/refresh", h.Refresh)
	app.Post("/api/v1/auth/logout", middleware.Auth(testTokens), h.Logout)
	return app
}

func jsonRequest(path, body string) *http.Request {
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	req.Header.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSON)
	return req
}

// call runs req, checks the response against the OpenAPI spec and decodes it.
func call(t *testing.T, app *fiber.App, req *http.Request) (*http.Response, map[string]any) {
	t.Helper()
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	contract.Load(t).AssertResponse(t, req, resp)
	var body map[string]any
	if resp.StatusCode != fiber.StatusNoContent {
		if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
			t.Fatalf("decode body: %v", err)
		}
	}
	return resp, body
}

func TestAuthSignIn(t *testing.T) {
	// Arrange
	user := model.User{ID: uuid.Must(uuid.NewV7()), Phone: "+6281234567890", CreatedAt: time.Now()}
	fake := &fakeAuth{signInResult: service.SignInResult{
		User:      user,
		Tokens:    service.TokenPair{AccessToken: "access", RefreshToken: "refresh", ExpiresIn: 15 * time.Minute},
		IsNewUser: true,
	}}
	app := newAuthApp(fake)
	req := jsonRequest("/api/v1/auth/sign-in",
		`{"firebase_id_token":"fb-token","device_name":"Samsung Galaxy A54","device_platform":"android","fcm_token":"fcm"}`)

	// Act
	resp, body := call(t, app, req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	if fake.gotIDToken != "fb-token" || fake.gotDevice.Name != "Samsung Galaxy A54" ||
		fake.gotDevice.Platform != model.DevicePlatformAndroid || fake.gotDevice.FCMToken == nil || *fake.gotDevice.FCMToken != "fcm" {
		t.Errorf("service got %q, %+v", fake.gotIDToken, fake.gotDevice)
	}
	data := body["data"].(map[string]any)
	tokens := data["tokens"].(map[string]any)
	if tokens["token_type"] != "Bearer" || tokens["expires_in"] != float64(900) || data["is_new_user"] != true || data["pin_set"] != false {
		t.Errorf("data %v", data)
	}
}

func TestAuthSignInErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		body       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"missing fields", `{}`, nil, 422, "validation_error"},
		{"unknown platform", `{"firebase_id_token":"t","device_name":"d","device_platform":"windows"}`, nil, 422, "validation_error"},
		{"rejected token", `{"firebase_id_token":"t","device_name":"d","device_platform":"ios"}`, model.ErrOTPInvalid, 401, "otp_invalid"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			app := newAuthApp(&fakeAuth{err: tt.serviceErr})

			// Act
			resp, body := call(t, app, jsonRequest("/api/v1/auth/sign-in", tt.body))

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestAuthRefresh(t *testing.T) {
	// Arrange
	fake := &fakeAuth{pair: service.TokenPair{AccessToken: "access2", RefreshToken: "refresh2", ExpiresIn: 15 * time.Minute}}
	app := newAuthApp(fake)

	// Act
	resp, body := call(t, app, jsonRequest("/api/v1/auth/refresh", `{"refresh_token":"refresh1"}`))

	// Assert
	if resp.StatusCode != 200 || fake.gotRefresh != "refresh1" {
		t.Fatalf("status %d, service got %q", resp.StatusCode, fake.gotRefresh)
	}
	if data := body["data"].(map[string]any); data["refresh_token"] != "refresh2" || data["access_token"] != "access2" {
		t.Errorf("data %v", data)
	}
}

func TestAuthRefreshInvalid(t *testing.T) {
	// Arrange
	app := newAuthApp(&fakeAuth{err: model.ErrRefreshTokenInvalid})

	// Act
	resp, body := call(t, app, jsonRequest("/api/v1/auth/refresh", `{"refresh_token":"stolen"}`))

	// Assert
	if resp.StatusCode != 401 || body["code"] != "refresh_token_invalid" {
		t.Errorf("status %d code %v", resp.StatusCode, body["code"])
	}
}

func TestAuthLogout(t *testing.T) {
	// Arrange
	fake := &fakeAuth{}
	app := newAuthApp(fake)
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	token, _, err := testTokens.Issue(userID, sessionID)
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil)
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)

	// Act
	resp, _ := call(t, app, req)

	// Assert
	if resp.StatusCode != 204 {
		t.Fatalf("status %d, want 204", resp.StatusCode)
	}
	if fake.gotUser != userID || fake.gotSession != sessionID {
		t.Errorf("service got %s/%s, want %s/%s", fake.gotUser, fake.gotSession, userID, sessionID)
	}
}

func TestAuthLogoutWithoutToken(t *testing.T) {
	// Arrange
	app := newAuthApp(&fakeAuth{})

	// Act
	resp, body := call(t, app, httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil))

	// Assert
	if resp.StatusCode != 401 || body["code"] != "unauthorized" {
		t.Errorf("status %d code %v", resp.StatusCode, body["code"])
	}
}
