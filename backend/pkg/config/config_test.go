package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// required holds the keys without a default, valid for development.
var required = map[string]string{
	"APP_ENV":             "development",
	"APP_PUBLIC_BASE_URL": "http://localhost:8080",
	"DATABASE_URL":        "postgres://giliran:CHANGE_ME@localhost:5432/giliran?sslmode=disable",
	"JWT_SECRET":          strings.Repeat("s", 32),
	"OTP_SECRET":          strings.Repeat("o", 32),
	"MINIO_ENDPOINT":      "localhost:9000",
	"MINIO_ACCESS_KEY":    "giliran",
	"MINIO_SECRET_KEY":    "CHANGE_ME",
}

// environ returns an EnvironFunc with required plus overrides; an empty
// override value removes the key.
func environ(overrides map[string]string) func() []string {
	return func() []string {
		vars := map[string]string{}
		for k, v := range required {
			vars[k] = v
		}
		for k, v := range overrides {
			if v == "" {
				delete(vars, k)
				continue
			}
			vars[k] = v
		}
		out := make([]string, 0, len(vars))
		for k, v := range vars {
			out = append(out, k+"="+v)
		}
		return out
	}
}

// writeEnvFile writes content to a temporary .env and returns its path.
func writeEnvFile(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), ".env")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestLoadDefaults(t *testing.T) {
	// Arrange
	missing := filepath.Join(t.TempDir(), ".env")

	// Act
	cfg, err := load(missing, environ(nil))

	// Assert
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if cfg.HTTP.Addr() != "0.0.0.0:8080" {
		t.Errorf("addr %q", cfg.HTTP.Addr())
	}
	if cfg.HTTP.ReadTimeout != 10*time.Second || cfg.JWT.RefreshTTL != 720*time.Hour {
		t.Errorf("durations %s / %s", cfg.HTTP.ReadTimeout, cfg.JWT.RefreshTTL)
	}
	if cfg.Log.Level != "info" || cfg.Log.Format != "json" {
		t.Errorf("log %+v", cfg.Log)
	}
	if cfg.App.Location == nil || cfg.App.Location.String() != "Asia/Jakarta" {
		t.Errorf("location %v", cfg.App.Location)
	}
	if cfg.OTP.TTL != 10*time.Minute || cfg.OTP.ResendInterval != time.Minute || cfg.OTP.MaxAttempts != 5 {
		t.Errorf("otp %+v", cfg.OTP)
	}
	if cfg.SMTP.TLS != SMTPTLSStartTLS || cfg.SMTP.Port != 587 || cfg.SMTP.DailyLimit != 100 {
		t.Errorf("smtp %+v", cfg.SMTP)
	}
	if cfg.Worker.OTPExpireCron != "* * * * *" || cfg.Retention.OTPRequests != 24*time.Hour {
		t.Errorf("otp expire cron %q, retention %s", cfg.Worker.OTPExpireCron, cfg.Retention.OTPRequests)
	}
	if cfg.HTTP.TrustedProxies == nil || len(cfg.HTTP.TrustedProxies) != 0 {
		t.Errorf("trusted proxies %#v, want empty non-nil", cfg.HTTP.TrustedProxies)
	}
}

func TestLoadPrecedence(t *testing.T) {
	// Arrange
	path := writeEnvFile(t, strings.Join([]string{
		"HTTP_PORT=9090",
		"LOG_LEVEL=debug",
		"HTTP_CORS_ALLOW_ORIGINS=http://a.test, http://b.test",
		`WORKER_REMINDER_CRON="30 7 * * *"`,
	}, "\n"))

	// Act
	cfg, err := load(path, environ(map[string]string{"LOG_LEVEL": "warn"}))

	// Assert
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if cfg.HTTP.Port != 9090 {
		t.Errorf("port %d, want the file's 9090", cfg.HTTP.Port)
	}
	if cfg.Log.Level != "warn" {
		t.Errorf("level %q, want the environment's warn", cfg.Log.Level)
	}
	if got := strings.Join(cfg.HTTP.CORSAllowOrigins, "|"); got != "http://a.test|http://b.test" {
		t.Errorf("origins %q", got)
	}
	if cfg.Worker.ReminderCron != "30 7 * * *" {
		t.Errorf("cron %q", cfg.Worker.ReminderCron)
	}
	if cfg.Log.Format != "json" {
		t.Errorf("format %q, want the default json", cfg.Log.Format)
	}
}

func TestLoadInvalid(t *testing.T) {
	// Arrange
	tests := []struct {
		name      string
		overrides map[string]string
		wantErr   string
	}{
		{"missing jwt secret", map[string]string{"JWT_SECRET": ""}, "JWT_SECRET: is required"},
		{"short jwt secret", map[string]string{"JWT_SECRET": "too-short"}, "JWT_SECRET: must be at least 32 bytes, got 9"},
		{"missing otp secret", map[string]string{"OTP_SECRET": ""}, "OTP_SECRET: is required"},
		{"short otp secret", map[string]string{"OTP_SECRET": "too-short"}, "OTP_SECRET: must be at least 32 bytes, got 9"},
		{"resend interval not shorter than ttl", map[string]string{"OTP_RESEND_INTERVAL": "10m"}, "OTP_RESEND_INTERVAL: must be shorter than OTP_TTL"},
		{"negative max resends", map[string]string{"OTP_MAX_RESENDS": "-1"}, "OTP_MAX_RESENDS: must be at least 0"},
		{"unknown smtp tls", map[string]string{"SMTP_TLS": "ssl"}, "SMTP_TLS: must be one of"},
		{"smtp tls none in production", map[string]string{"APP_ENV": "production", "SMTP_TLS": "none"}, "SMTP_TLS: must not be none in production"},
		{"unparsable smtp from", map[string]string{"SMTP_FROM": "Giliran"}, "SMTP_FROM: must be an address"},
		{"bad otp expire cron", map[string]string{"WORKER_OTP_EXPIRE_CRON": "every minute"}, "WORKER_OTP_EXPIRE_CRON: must be a five-field cron spec"},
		{"bad duration", map[string]string{"HTTP_READ_TIMEOUT": "ten seconds"}, "http_read_timeout"},
		{"bad number", map[string]string{"HTTP_PORT": "eighty"}, "http_port"},
		{"port out of range", map[string]string{"HTTP_PORT": "70000"}, "HTTP_PORT: must be between 1 and 65535"},
		{"unknown env", map[string]string{"APP_ENV": "prod"}, "APP_ENV: must be one of"},
		{"unknown timezone", map[string]string{"APP_TIMEZONE": "Mars/Olympus"}, "APP_TIMEZONE: unknown time zone"},
		{"relative base url", map[string]string{"APP_PUBLIC_BASE_URL": "giliran.test"}, "APP_PUBLIC_BASE_URL"},
		{"non-postgres database url", map[string]string{"DATABASE_URL": "mysql://localhost/giliran"}, "DATABASE_URL: must be an absolute postgres"},
		{"bad log format", map[string]string{"LOG_FORMAT": "xml"}, "LOG_FORMAT"},
		{"body limit below upload", map[string]string{"HTTP_BODY_LIMIT": "1024"}, "HTTP_BODY_LIMIT: must be at least UPLOAD_MAX_BYTES"},
		{"refresh not longer than access", map[string]string{"JWT_REFRESH_TTL": "15m"}, "JWT_REFRESH_TTL: must be longer"},
		{"min conns over max", map[string]string{"DATABASE_MIN_CONNS": "30"}, "DATABASE_MIN_CONNS: must not exceed"},
		{"placeholder in production", map[string]string{"APP_ENV": "production"}, "MINIO_SECRET_KEY: still contains the CHANGE_ME placeholder"},
		{"bad cron", map[string]string{"WORKER_CLEANUP_CRON": "every night"}, "WORKER_CLEANUP_CRON: must be a five-field cron spec"},
		{"cron with time zone", map[string]string{"WORKER_REMINDER_CRON": "CRON_TZ=UTC 0 8 * * *"}, "WORKER_REMINDER_CRON: must not set a time zone"},
		{"cors wildcard in production", map[string]string{"APP_ENV": "production", "HTTP_CORS_ALLOW_ORIGINS": "*"}, "HTTP_CORS_ALLOW_ORIGINS: must not be * in production"},
	}
	missing := filepath.Join(t.TempDir(), ".env")

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := load(missing, environ(tt.overrides))

			// Assert
			if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("err = %v, want it to contain %q", err, tt.wantErr)
			}
		})
	}
}

func TestLoadReportsAllProblems(t *testing.T) {
	// Arrange
	missing := filepath.Join(t.TempDir(), ".env")
	env := environ(map[string]string{"JWT_SECRET": "", "MINIO_ENDPOINT": "", "LOG_LEVEL": "loud"})

	// Act
	_, err := load(missing, env)

	// Assert
	for _, want := range []string{"JWT_SECRET", "MINIO_ENDPOINT", "LOG_LEVEL"} {
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("err = %v, want it to mention %s", err, want)
		}
	}
}
