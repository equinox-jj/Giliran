package main

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
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/internal/controller"
	"github.com/equinox-jj/Giliran/backend/internal/routes"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/test/contract"
)

// testConfig is a valid config without loading files or the environment.
func testConfig() *config.Config {
	return &config.Config{
		App:  config.App{Name: "giliran-test", Env: config.EnvDevelopment},
		HTTP: config.HTTP{BodyLimit: 1 << 20, CORSAllowOrigins: []string{"http://localhost:3000"}},
		JWT:  config.JWT{Secret: strings.Repeat("s", 32), Issuer: "giliran-test", Audience: "giliran-test", AccessTTL: 15 * time.Minute},
	}
}

// testBody is a request DTO for the /bind route.
type testBody struct {
	Name string `json:"name" validate:"required,min=3"`
}

// newTestApp is the production app plus /panic and /bind routes.
func newTestApp() *fiber.App {
	cfg := testConfig()
	app := newFiberApp(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	routes.Register(routes.Params{
		App:    app,
		Config: cfg,
		Tokens: security.NewTokenIssuer(cfg, clock.System{}),
		Health: controller.NewHealthController(),
		Auth:   controller.NewAuthController(nil), // auth routes are tested in internal/controller
	})
	app.Get("/panic", func(fiber.Ctx) error { panic("boom") })
	app.Post("/bind", func(c fiber.Ctx) error {
		var body testBody
		if err := c.Bind().Body(&body); err != nil {
			return err
		}
		return c.SendStatus(fiber.StatusNoContent)
	})
	return app
}

// do sends req and decodes the JSON body.
func do(t *testing.T, app *fiber.App, req *http.Request) (*http.Response, map[string]any) {
	t.Helper()
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return resp, body
}

func TestOptionsWiring(t *testing.T) {
	// Act
	err := fx.ValidateApp(options())

	// Assert
	if err != nil {
		t.Errorf("fx graph: %v", err)
	}
}

func TestServerResponses(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		method     string
		path       string
		wantStatus int
		wantCode   string
	}{
		{"unknown route", http.MethodGet, "/api/v1/nope", 404, "not_found"},
		{"wrong method", http.MethodPost, "/api/v1/health", 404, "not_found"},
		{"panic", http.MethodGet, "/panic", 500, "internal_error"},
	}
	app := newTestApp()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			resp, body := do(t, app, httptest.NewRequest(tt.method, tt.path, nil))

			// Assert
			if resp.StatusCode != tt.wantStatus {
				t.Errorf("status %d, want %d", resp.StatusCode, tt.wantStatus)
			}
			if body["code"] != tt.wantCode {
				t.Errorf("code %v, want %s", body["code"], tt.wantCode)
			}
			rid := resp.Header.Get(fiber.HeaderXRequestID)
			if rid == "" || body["request_id"] != rid {
				t.Errorf("request_id %v, header %q", body["request_id"], rid)
			}
		})
	}
}

func TestServerBindValidates(t *testing.T) {
	// Arrange
	app := newTestApp()
	req := httptest.NewRequest(http.MethodPost, "/bind", strings.NewReader(`{"name":"ab"}`))
	req.Header.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSON)

	// Act
	resp, body := do(t, app, req)

	// Assert
	if resp.StatusCode != 422 || body["code"] != "validation_error" {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	errs, _ := body["errors"].([]any)
	first, _ := errs[0].(map[string]any)
	if len(errs) != 1 || first["field"] != "name" || first["code"] != "min_length" {
		t.Errorf("errors %v, want one name/min_length", errs)
	}
}

func TestServerHealth(t *testing.T) {
	// Arrange
	app := newTestApp()
	spec := contract.Load(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)

	// Act
	resp, err := app.Test(req)

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	spec.AssertResponse(t, req, resp)
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Errorf("status %d, want 200", resp.StatusCode)
	}
	data, _ := body["data"].(map[string]any)
	if data["status"] != "ok" {
		t.Errorf("body %v", body)
	}
}

func TestServerKeepsIncomingRequestID(t *testing.T) {
	// Arrange
	app := newTestApp()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/nope", nil)
	req.Header.Set(fiber.HeaderXRequestID, "req_from_client")

	// Act
	resp, body := do(t, app, req)

	// Assert
	if resp.Header.Get(fiber.HeaderXRequestID) != "req_from_client" || body["request_id"] != "req_from_client" {
		t.Errorf("header %q, body %v", resp.Header.Get(fiber.HeaderXRequestID), body["request_id"])
	}
}

func TestServerCORS(t *testing.T) {
	// Arrange
	app := newTestApp()
	req := httptest.NewRequest(http.MethodOptions, "/api/v1/health", nil)
	req.Header.Set(fiber.HeaderOrigin, "http://localhost:3000")
	req.Header.Set(fiber.HeaderAccessControlRequestMethod, http.MethodGet)

	// Act
	resp, err := app.Test(req)

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if got := resp.Header.Get(fiber.HeaderAccessControlAllowOrigin); got != "http://localhost:3000" {
		t.Errorf("Access-Control-Allow-Origin %q", got)
	}
}
