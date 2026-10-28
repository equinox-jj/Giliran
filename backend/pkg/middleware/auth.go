package middleware

import (
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/limiter"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

type (
	userIDKey    struct{}
	sessionIDKey struct{}
)

// Auth requires a valid access token in "Authorization: Bearer <token>" and
// stores its user and session IDs for UserID and SessionID. Access tokens are
// checked without a database lookup; a signed-out device keeps access until
// its token expires (at most JWT_ACCESS_TTL). Failures are 401 unauthorized.
func Auth(tokens *security.TokenIssuer) fiber.Handler {
	return func(c fiber.Ctx) error {
		if err := authenticate(c, tokens); err != nil {
			return err
		}
		return c.Next()
	}
}

// OptionalAuth is Auth for routes that also serve anonymous callers: with no
// Authorization header the request continues signed out, and UserIDOpt
// reports false. A header that is present must still hold a valid token, so
// a client with an expired one gets 401 and refreshes instead of silently
// acting anonymously.
func OptionalAuth(tokens *security.TokenIssuer) fiber.Handler {
	return func(c fiber.Ctx) error {
		if c.Get(fiber.HeaderAuthorization) == "" {
			return c.Next()
		}
		if err := authenticate(c, tokens); err != nil {
			return err
		}
		return c.Next()
	}
}

func authenticate(c fiber.Ctx, tokens *security.TokenIssuer) error {
	scheme, token, ok := strings.Cut(c.Get(fiber.HeaderAuthorization), " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") || token == "" {
		return model.ErrUnauthorized
	}
	userID, sessionID, err := tokens.Parse(token)
	if err != nil {
		return err
	}
	c.Locals(userIDKey{}, userID)
	c.Locals(sessionIDKey{}, sessionID)
	return nil
}

// UserID is the signed-in user on a route behind Auth.
func UserID(c fiber.Ctx) uuid.UUID {
	id, _ := c.Locals(userIDKey{}).(uuid.UUID)
	return id
}

// UserIDOpt is the signed-in user on a route behind OptionalAuth, and false
// when the caller sent no token.
func UserIDOpt(c fiber.Ctx) (uuid.UUID, bool) {
	id, ok := c.Locals(userIDKey{}).(uuid.UUID)
	return id, ok
}

// SessionID is the current session on a route behind Auth.
func SessionID(c fiber.Ctx) uuid.UUID {
	id, _ := c.Locals(sessionIDKey{}).(uuid.UUID)
	return id
}

// RateLimit allows limit requests per client IP in each window. Over the
// limit it answers 429 rate_limit_exceeded with Retry-After. Counters live in
// memory, so each API instance limits on its own.
func RateLimit(limit int, window time.Duration) fiber.Handler {
	return rateLimit(limit, window, func(c fiber.Ctx) string { return c.IP() })
}

// RateLimitByUser is RateLimit keyed by the signed-in user instead of the IP,
// so one account cannot dodge it by switching networks. Register it after
// Auth. One handler shares its counters across every route it is used on.
func RateLimitByUser(limit int, window time.Duration) fiber.Handler {
	return rateLimit(limit, window, func(c fiber.Ctx) string { return UserID(c).String() })
}

func rateLimit(limit int, window time.Duration, key func(fiber.Ctx) string) fiber.Handler {
	return limiter.New(limiter.Config{
		Max:          limit,
		Expiration:   window,
		KeyGenerator: key,
		LimitReached: func(fiber.Ctx) error {
			return model.ErrRateLimitExceeded // Retry-After is already set
		},
	})
}
