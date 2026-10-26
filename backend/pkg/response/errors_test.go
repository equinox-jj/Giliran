package response

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/requestid"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// newErrorApp returns an app whose GET /fail returns err, using ErrorHandler
// and the requestid middleware, logging into logs.
func newErrorApp(err error, logs io.Writer) *fiber.App {
	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler(slog.New(slog.NewTextHandler(logs, nil)))})
	app.Use(requestid.New())
	app.Get("/fail", func(fiber.Ctx) error { return err })
	return app
}

// decode reads the response body into a generic map.
func decode(t *testing.T, resp *http.Response) map[string]any {
	t.Helper()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return body
}

func TestStatusFor(t *testing.T) {
	// Arrange
	tests := []struct {
		kind model.ErrorKind
		want int
	}{
		{model.KindInternal, 500},
		{model.KindBadRequest, 400},
		{model.KindUnauthenticated, 401},
		{model.KindForbidden, 403},
		{model.KindNotFound, 404},
		{model.KindConflict, 409},
		{model.KindTooLarge, 413},
		{model.KindUnsupportedType, 415},
		{model.KindInvalid, 422},
		{model.KindLocked, 423},
		{model.KindRateLimited, 429},
		{model.KindUnavailable, 503},
		{model.ErrorKind(99), 500},
	}

	for _, tt := range tests {
		t.Run(fmt.Sprint(tt.want), func(t *testing.T) {
			// Act
			got := statusFor(tt.kind)

			// Assert
			if got != tt.want {
				t.Errorf("got %d, want %d", got, tt.want)
			}
		})
	}
}

func TestErrorHandler(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		err        error
		wantStatus int
		wantCode   string
		wantType   string
		wantTitle  string
		wantDetail string
	}{
		{"wrapped sentinel", fmt.Errorf("load group: %w", model.ErrGroupNotFound), 404, "group_not_found", "about:blank", "Not Found", "Group not found."},
		{"with detail", model.ErrPeriodNotOpen.WithDetail("Period 3 is closed."), 409, "period_not_open", "about:blank", "Conflict", "Period 3 is closed."},
		{"locked", model.ErrPINLocked, 423, "pin_locked", "about:blank", "Locked", "Too many wrong PIN attempts."},
		{"fiber bad json", fiber.NewError(fiber.StatusBadRequest, "invalid character"), 400, "bad_request", "about:blank", "Bad Request", "The request is malformed."},
		{"fiber body limit", fiber.ErrRequestEntityTooLarge, 413, "file_too_large", "about:blank", "Request Entity Too Large", "Upload is over 5 MB."},
		{"fiber teapot", fiber.ErrTeapot, 400, "bad_request", "about:blank", "Bad Request", "The request is malformed."},
		{"fiber 502", fiber.ErrBadGateway, 500, "internal_error", "about:blank", "Internal Server Error", "Unexpected error."},
		{"unknown error", errors.New(`pq: duplicate key value violates unique constraint "users_phone_key"`), 500, "internal_error", "about:blank", "Internal Server Error", "Unexpected error."},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := newErrorApp(tt.err, io.Discard)

			// Act
			resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/fail", nil))

			// Assert
			if err != nil {
				t.Fatalf("app.Test: %v", err)
			}
			if resp.StatusCode != tt.wantStatus {
				t.Errorf("status %d, want %d", resp.StatusCode, tt.wantStatus)
			}
			if ct := resp.Header.Get(fiber.HeaderContentType); !strings.HasPrefix(ct, "application/problem+json") {
				t.Errorf("content type %q", ct)
			}
			body := decode(t, resp)
			want := map[string]any{
				"type":       tt.wantType,
				"title":      tt.wantTitle,
				"status":     float64(tt.wantStatus),
				"detail":     tt.wantDetail,
				"code":       tt.wantCode,
				"request_id": resp.Header.Get(fiber.HeaderXRequestID),
			}
			for k, v := range want {
				if body[k] != v {
					t.Errorf("%s = %v, want %v", k, body[k], v)
				}
			}
			if _, ok := body["errors"]; ok {
				t.Errorf("unexpected errors[]: %v", body["errors"])
			}
		})
	}
}

func TestErrorHandlerRetryAfter(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		err  error
		want string
	}{
		{"rounds up to whole seconds", model.ErrPINLocked.WithRetryAfter(90*time.Second + time.Millisecond), "91"},
		{"absent when zero", model.ErrPINLocked, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			app := newErrorApp(tt.err, io.Discard)

			// Act
			resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/fail", nil))

			// Assert
			if err != nil {
				t.Fatalf("app.Test: %v", err)
			}
			if got := resp.Header.Get(fiber.HeaderRetryAfter); got != tt.want {
				t.Errorf("Retry-After %q, want %q", got, tt.want)
			}
		})
	}
}

func TestErrorHandlerUnknownRoute(t *testing.T) {
	// Arrange
	app := newErrorApp(nil, io.Discard)

	// Act
	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/nope", nil))

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != 404 {
		t.Errorf("status %d, want 404", resp.StatusCode)
	}
	if code := decode(t, resp)["code"]; code != "not_found" {
		t.Errorf("code %v, want not_found", code)
	}
}

func TestErrorHandlerValidation(t *testing.T) {
	// Arrange
	app := newErrorApp(model.NewValidationError(
		model.FieldError{Field: "amount", Code: model.FieldMinimumValue, Message: "Iuran minimal Rp10.000."},
		model.FieldError{Field: "total_slots", Code: model.FieldMaximumValue, Message: "Maksimal 50 slot."},
	), io.Discard)

	// Act
	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/fail", nil))

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != 422 {
		t.Errorf("status %d, want 422", resp.StatusCode)
	}
	body := decode(t, resp)
	if body["type"] != "https://api.giliran.monai.my.id/problems/validation-error" || body["title"] != "Validation failed" {
		t.Errorf("type/title = %v / %v", body["type"], body["title"])
	}
	fields, _ := body["errors"].([]any)
	if len(fields) != 2 {
		t.Fatalf("errors = %v, want 2 entries", body["errors"])
	}
	first, _ := fields[0].(map[string]any)
	if first["field"] != "amount" || first["code"] != "minimum_value" || first["message"] != "Iuran minimal Rp10.000." {
		t.Errorf("errors[0] = %v", first)
	}
}

func TestErrorHandlerExtensions(t *testing.T) {
	// Arrange
	app := newErrorApp(model.ErrPaymentsIncomplete.
		WithDetail("8 of 10 payments are paid. Confirm to draw anyway.").
		WithExtensions(map[string]any{"paid_count": 8, "total_count": 10, "code": "spoofed"}), io.Discard)

	// Act
	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/fail", nil))

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	body := decode(t, resp)
	if body["type"] != "https://api.giliran.monai.my.id/problems/payments-incomplete" || body["title"] != "Payments incomplete" {
		t.Errorf("type/title = %v / %v", body["type"], body["title"])
	}
	if body["paid_count"] != float64(8) || body["total_count"] != float64(10) {
		t.Errorf("extensions = %v / %v", body["paid_count"], body["total_count"])
	}
	if body["code"] != "payments_incomplete" {
		t.Errorf("code = %v, standard member must win over extension", body["code"])
	}
}

func TestErrorHandlerHidesDatabaseErrors(t *testing.T) {
	// Arrange
	pgErr := &pgconn.PgError{
		Severity:       "ERROR",
		Code:           "23505",
		Message:        `duplicate key value violates unique constraint "users_phone_active_uq"`,
		Detail:         "Key (phone)=(+6281234567890) already exists.",
		TableName:      "users",
		ConstraintName: "users_phone_active_uq",
	}
	tests := []struct {
		name string
		err  error
	}{
		{"pg error", pgErr},
		{"wrapped pg error", fmt.Errorf("insert user: %w", pgErr)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := newErrorApp(tt.err, io.Discard)

			// Act
			resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/fail", nil))

			// Assert
			if err != nil {
				t.Fatalf("app.Test: %v", err)
			}
			raw, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("read body: %v", err)
			}
			if resp.StatusCode != 500 {
				t.Errorf("status %d, want 500", resp.StatusCode)
			}
			for _, leak := range []string{"users_phone_active_uq", "23505", "SQLSTATE", "+6281234567890", "duplicate key", "insert user"} {
				if bytes.Contains(raw, []byte(leak)) {
					t.Errorf("body leaks %q: %s", leak, raw)
				}
			}
			var body map[string]any
			if err := json.Unmarshal(raw, &body); err != nil {
				t.Fatalf("decode body: %v", err)
			}
			if body["code"] != "internal_error" || body["detail"] != "Unexpected error." {
				t.Errorf("body %v, want a bare internal_error", body)
			}
		})
	}
}

func TestErrorHandlerLogsOnlyServerErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name    string
		err     error
		wantLog bool
	}{
		{"unknown error", errors.New("pq: connection refused"), true},
		{"unavailable", fmt.Errorf("ping: %w: %w", model.ErrServiceUnavailable, errors.New("dial tcp: refused")), true},
		{"domain error", model.ErrGroupFull, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var logs bytes.Buffer
			app := newErrorApp(tt.err, &logs)

			// Act
			resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/fail", nil))

			// Assert
			if err != nil {
				t.Fatalf("app.Test: %v", err)
			}
			logged := strings.Contains(logs.String(), "request failed")
			if logged != tt.wantLog {
				t.Errorf("logged = %v, want %v; logs: %s", logged, tt.wantLog, logs.String())
			}
			if tt.wantLog && !strings.Contains(logs.String(), resp.Header.Get(fiber.HeaderXRequestID)) {
				t.Errorf("log line has no request_id: %s", logs.String())
			}
		})
	}
}
