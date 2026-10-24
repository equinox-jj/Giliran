package response

import (
	"encoding/json"
	"errors"
	"log/slog"
	"maps"
	"net/http"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/requestid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

const (
	problemContentType = "application/problem+json"
	problemTypeBase    = "https://api.giliran.monai.my.id/problems/"
)

// customTypes are the problem types the spec documents beyond about:blank.
var customTypes = map[string]struct{ uri, title string }{
	model.ErrValidation.Code:         {problemTypeBase + "validation-error", "Validation failed"},
	model.ErrPaymentsIncomplete.Code: {problemTypeBase + "payments-incomplete", "Payments incomplete"},
}

// Problem is an RFC 9457 problem details body with Giliran's code and
// request_id members. Extensions are merged into the top-level object.
type Problem struct {
	Type       string
	Title      string
	Status     int
	Detail     string
	Code       string
	RequestID  string
	Errors     []FieldError
	Extensions map[string]any
}

// FieldError is one entry of errors[] on a validation_error.
type FieldError struct {
	Field   string `json:"field"`
	Code    string `json:"code"`
	Message string `json:"message"`
}

// MarshalJSON flattens Extensions next to the standard members, which win on
// a name clash.
func (p Problem) MarshalJSON() ([]byte, error) {
	m := make(map[string]any, len(p.Extensions)+7)
	maps.Copy(m, p.Extensions)
	m["type"] = p.Type
	m["title"] = p.Title
	m["status"] = p.Status
	m["detail"] = p.Detail
	m["code"] = p.Code
	m["request_id"] = p.RequestID
	if len(p.Errors) > 0 {
		m["errors"] = p.Errors
	}
	return json.Marshal(m)
}

// statusFor maps a domain error kind to its HTTP status.
func statusFor(k model.ErrorKind) int {
	switch k {
	case model.KindBadRequest:
		return fiber.StatusBadRequest
	case model.KindUnauthenticated:
		return fiber.StatusUnauthorized
	case model.KindForbidden:
		return fiber.StatusForbidden
	case model.KindNotFound:
		return fiber.StatusNotFound
	case model.KindConflict:
		return fiber.StatusConflict
	case model.KindTooLarge:
		return fiber.StatusRequestEntityTooLarge
	case model.KindUnsupportedType:
		return fiber.StatusUnsupportedMediaType
	case model.KindInvalid:
		return fiber.StatusUnprocessableEntity
	case model.KindLocked:
		return fiber.StatusLocked
	case model.KindRateLimited:
		return fiber.StatusTooManyRequests
	case model.KindUnavailable:
		return fiber.StatusServiceUnavailable
	}
	return fiber.StatusInternalServerError
}

// fromFiberStatus maps errors Fiber raises itself (bad JSON, unknown route,
// body limit, limiter) to a sentinel.
func fromFiberStatus(status int) *model.Error {
	switch status {
	case fiber.StatusBadRequest:
		return model.ErrBadRequest
	case fiber.StatusUnauthorized:
		return model.ErrUnauthorized
	case fiber.StatusNotFound, fiber.StatusMethodNotAllowed:
		return model.ErrNotFound
	case fiber.StatusRequestEntityTooLarge:
		return model.ErrFileTooLarge
	case fiber.StatusUnsupportedMediaType:
		return model.ErrUnsupportedMediaType
	case fiber.StatusUnprocessableEntity:
		return model.ErrValidation
	case fiber.StatusTooManyRequests:
		return model.ErrRateLimitExceeded
	case fiber.StatusServiceUnavailable:
		return model.ErrServiceUnavailable
	}
	if status >= 400 && status < 500 {
		return model.ErrBadRequest
	}
	return model.ErrInternal
}

// newProblem builds the response body for e.
func newProblem(e *model.Error, requestID string) Problem {
	status := statusFor(e.Kind)
	p := Problem{
		Type:       "about:blank",
		Title:      http.StatusText(status),
		Status:     status,
		Detail:     e.Message,
		Code:       e.Code,
		RequestID:  requestID,
		Extensions: e.Extensions,
	}
	if t, ok := customTypes[e.Code]; ok {
		p.Type, p.Title = t.uri, t.title
	}
	for _, f := range e.Fields {
		p.Errors = append(p.Errors, FieldError{Field: f.Field, Code: string(f.Code), Message: f.Message})
	}
	return p
}

// ErrorHandler is the app-wide fiber.Config.ErrorHandler. Typed model errors
// keep their code; anything unknown is logged and sent as a bare
// internal_error so SQL errors and stack traces never reach the client.
func ErrorHandler(log *slog.Logger) fiber.ErrorHandler {
	return func(c fiber.Ctx, err error) error {
		rid := requestid.FromContext(c)

		var me *model.Error
		var fe *fiber.Error
		switch {
		case errors.As(err, &me):
		case errors.As(err, &fe):
			me = fromFiberStatus(fe.Code)
		default:
			me = model.ErrInternal
		}
		if me.Kind == model.KindInternal {
			log.ErrorContext(c.Context(), "request failed", "error", err, "request_id", rid,
				"method", c.Method(), "path", c.Path())
		}

		p := newProblem(me, rid)
		return c.Status(p.Status).JSON(p, problemContentType)
	}
}
