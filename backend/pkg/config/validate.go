package config

import (
	"errors"
	"fmt"
	"net/url"
	"slices"
	"strings"
	"time"
)

// minJWTSecretBytes is the shortest HS256 secret accepted (RFC 7518 §3.2).
const minJWTSecretBytes = 32

// placeholder is the value .env.example uses for secrets.
const placeholder = "CHANGE_ME"

// validator collects every problem so one startup reports them all.
type validator struct{ errs []error }

func (v *validator) fail(key, format string, args ...any) {
	v.errs = append(v.errs, fmt.Errorf("%s: %s", key, fmt.Sprintf(format, args...)))
}

func (v *validator) required(key, val string) {
	if strings.TrimSpace(val) == "" {
		v.fail(key, "is required")
	}
}

func (v *validator) oneOf(key, val string, allowed ...string) {
	if !slices.Contains(allowed, val) {
		v.fail(key, "must be one of %s, got %q", strings.Join(allowed, ", "), val)
	}
}

func (v *validator) positive(key string, d time.Duration) {
	if d <= 0 {
		v.fail(key, "must be a positive duration, got %s", d)
	}
}

func (v *validator) atLeast(key string, n, minimum int64) {
	if n < minimum {
		v.fail(key, "must be at least %d, got %d", minimum, n)
	}
}

func (v *validator) absoluteURL(key, val string, schemes ...string) {
	u, err := url.Parse(val)
	if err != nil || u.Host == "" || !slices.Contains(schemes, u.Scheme) {
		v.fail(key, "must be an absolute %s URL", strings.Join(schemes, " or "))
	}
}

// secret checks a required secret and, in production, rejects the
// .env.example placeholder.
func (v *validator) secret(key, val string, production bool) {
	v.required(key, val)
	if production && strings.Contains(val, placeholder) {
		v.fail(key, "still contains the %s placeholder", placeholder)
	}
}

func (c *Config) validate() error {
	var v validator
	prod := c.App.IsProduction()

	v.required("APP_NAME", c.App.Name)
	v.oneOf("APP_ENV", c.App.Env, EnvDevelopment, EnvStaging, EnvProduction)
	if _, err := time.LoadLocation(c.App.Timezone); err != nil || c.App.Timezone == "" {
		v.fail("APP_TIMEZONE", "unknown time zone %q", c.App.Timezone)
	}
	v.absoluteURL("APP_PUBLIC_BASE_URL", c.App.PublicBaseURL, "http", "https")

	if c.HTTP.Port < 1 || c.HTTP.Port > 65535 {
		v.fail("HTTP_PORT", "must be between 1 and 65535, got %d", c.HTTP.Port)
	}
	v.positive("HTTP_READ_TIMEOUT", c.HTTP.ReadTimeout)
	v.positive("HTTP_WRITE_TIMEOUT", c.HTTP.WriteTimeout)
	v.positive("HTTP_IDLE_TIMEOUT", c.HTTP.IdleTimeout)
	v.positive("HTTP_SHUTDOWN_TIMEOUT", c.HTTP.ShutdownTimeout)
	if c.HTTP.BodyLimit < c.MinIO.UploadMaxBytes {
		v.fail("HTTP_BODY_LIMIT", "must be at least UPLOAD_MAX_BYTES (%d), got %d", c.MinIO.UploadMaxBytes, c.HTTP.BodyLimit)
	}
	if prod && slices.Contains(c.HTTP.CORSAllowOrigins, "*") {
		v.fail("HTTP_CORS_ALLOW_ORIGINS", "must not be * in production")
	}

	v.oneOf("LOG_LEVEL", c.Log.Level, "debug", "info", "warn", "error")
	v.oneOf("LOG_FORMAT", c.Log.Format, "text", "json")

	v.secret("DATABASE_URL", c.Database.URL, prod)
	if c.Database.URL != "" {
		v.absoluteURL("DATABASE_URL", c.Database.URL, "postgres", "postgresql")
	}
	v.atLeast("DATABASE_MAX_CONNS", int64(c.Database.MaxConns), 1)
	v.atLeast("DATABASE_MIN_CONNS", int64(c.Database.MinConns), 0)
	if c.Database.MinConns > c.Database.MaxConns {
		v.fail("DATABASE_MIN_CONNS", "must not exceed DATABASE_MAX_CONNS")
	}
	v.positive("DATABASE_MAX_CONN_LIFETIME", c.Database.MaxConnLifetime)
	v.positive("DATABASE_MAX_CONN_IDLE_TIME", c.Database.MaxConnIdleTime)

	v.secret("JWT_SECRET", c.JWT.Secret, prod)
	if n := len(c.JWT.Secret); n > 0 && n < minJWTSecretBytes {
		v.fail("JWT_SECRET", "must be at least %d bytes, got %d", minJWTSecretBytes, n)
	}
	v.required("JWT_ISSUER", c.JWT.Issuer)
	v.required("JWT_AUDIENCE", c.JWT.Audience)
	v.positive("JWT_ACCESS_TTL", c.JWT.AccessTTL)
	v.positive("JWT_REFRESH_TTL", c.JWT.RefreshTTL)
	if c.JWT.RefreshTTL <= c.JWT.AccessTTL {
		v.fail("JWT_REFRESH_TTL", "must be longer than JWT_ACCESS_TTL")
	}

	v.atLeast("PIN_ARGON2_MEMORY_KIB", int64(c.PIN.Argon2MemoryKiB), 8*int64(c.PIN.Argon2Parallelism))
	v.atLeast("PIN_ARGON2_ITERATIONS", int64(c.PIN.Argon2Iterations), 1)
	v.atLeast("PIN_ARGON2_PARALLELISM", int64(c.PIN.Argon2Parallelism), 1)
	v.atLeast("PIN_ARGON2_SALT_LENGTH", int64(c.PIN.Argon2SaltLength), 16)
	v.atLeast("PIN_ARGON2_KEY_LENGTH", int64(c.PIN.Argon2KeyLength), 16)
	v.atLeast("PIN_MAX_ATTEMPTS", int64(c.PIN.MaxAttempts), 1)
	v.positive("PIN_LOCKOUT_DURATION", c.PIN.LockoutDuration)

	v.required("MINIO_ENDPOINT", c.MinIO.Endpoint)
	if c.MinIO.PublicURL != "" {
		v.absoluteURL("MINIO_PUBLIC_URL", c.MinIO.PublicURL, "http", "https")
	}
	v.secret("MINIO_ACCESS_KEY", c.MinIO.AccessKey, prod)
	v.secret("MINIO_SECRET_KEY", c.MinIO.SecretKey, prod)
	v.required("MINIO_BUCKET", c.MinIO.Bucket)
	v.positive("MINIO_PRESIGN_TTL", c.MinIO.PresignTTL)
	v.atLeast("UPLOAD_MAX_BYTES", int64(c.MinIO.UploadMaxBytes), 1)

	v.atLeast("RATE_LIMIT_OTP_MAX", int64(c.RateLimit.OTPMax), 1)
	v.positive("RATE_LIMIT_OTP_WINDOW", c.RateLimit.OTPWindow)
	v.atLeast("RATE_LIMIT_PIN_MAX", int64(c.RateLimit.PINMax), 1)
	v.positive("RATE_LIMIT_PIN_WINDOW", c.RateLimit.PINWindow)
	v.atLeast("RATE_LIMIT_WRITE_MAX", int64(c.RateLimit.WriteMax), 1)
	v.positive("RATE_LIMIT_WRITE_WINDOW", c.RateLimit.WriteWindow)
	v.atLeast("RATE_LIMIT_PUBLIC_MAX", int64(c.RateLimit.PublicMax), 1)
	v.positive("RATE_LIMIT_PUBLIC_WINDOW", c.RateLimit.PublicWindow)

	v.positive("IDEMPOTENCY_TTL", c.Idempotency.TTL)

	v.atLeast("WORKER_MAX_WORKERS", int64(c.Worker.MaxWorkers), 1)
	v.required("WORKER_REMINDER_CRON", c.Worker.ReminderCron)
	v.required("WORKER_CLEANUP_CRON", c.Worker.CleanupCron)

	v.positive("RETENTION_REVOKED_SESSIONS", c.Retention.RevokedSessions)
	v.positive("RETENTION_PAYMENT_PROOFS", c.Retention.PaymentProofs)

	return errors.Join(v.errs...)
}
