// Package middleware holds the Fiber middleware shared by every route.
package middleware

import (
	"fmt"
	"log/slog"
	"runtime/debug"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/requestid"
)

// RequestID reuses an incoming X-Request-ID or generates one, echoes it in the
// response and exposes it to response.ErrorHandler.
func RequestID() fiber.Handler {
	return requestid.New()
}

// Recover turns a panic into an error for response.ErrorHandler (500
// internal_error) and logs its stack trace. Register it after RequestID.
func Recover(log *slog.Logger) fiber.Handler {
	return recover.New(recover.Config{
		EnableStackTrace: true,
		StackTraceHandler: func(c fiber.Ctx, e any) {
			log.ErrorContext(c.Context(), "panic recovered", "panic", fmt.Sprint(e),
				"request_id", requestid.FromContext(c), "stack", string(debug.Stack()))
		},
	})
}

// CORS allows browser calls from origins. The Android app sends no Origin,
// so callers skip this middleware when origins is empty.
func CORS(origins []string) fiber.Handler {
	return cors.New(cors.Config{
		AllowOrigins:  origins,
		AllowHeaders:  []string{fiber.HeaderAuthorization, fiber.HeaderContentType, "Idempotency-Key", fiber.HeaderXRequestID},
		ExposeHeaders: []string{fiber.HeaderLocation, fiber.HeaderXRequestID, fiber.HeaderRetryAfter},
	})
}
