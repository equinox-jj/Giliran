// Package config loads the app configuration from defaults, an optional .env
// file and the real environment, in that order of precedence (lowest first).
package config

import (
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"time"
	_ "time/tzdata" // APP_TIMEZONE must resolve even in a scratch image

	"github.com/go-viper/mapstructure/v2"
	"github.com/knadh/koanf/parsers/dotenv"
	"github.com/knadh/koanf/providers/confmap"
	"github.com/knadh/koanf/providers/env/v2"
	"github.com/knadh/koanf/providers/file"
	"github.com/knadh/koanf/v2"
)

// Config mirrors .env.example. Every key is the lowercased variable name, so
// HTTP_READ_TIMEOUT is `koanf:"http_read_timeout"`; sections are squashed.
type Config struct {
	App         App         `koanf:",squash"`
	HTTP        HTTP        `koanf:",squash"`
	Log         Log         `koanf:",squash"`
	Database    Database    `koanf:",squash"`
	JWT         JWT         `koanf:",squash"`
	PIN         PIN         `koanf:",squash"`
	Firebase    Firebase    `koanf:",squash"`
	MinIO       MinIO       `koanf:",squash"`
	RateLimit   RateLimit   `koanf:",squash"`
	Idempotency Idempotency `koanf:",squash"`
	Worker      Worker      `koanf:",squash"`
	Retention   Retention   `koanf:",squash"`
}

// Environment names accepted by APP_ENV.
const (
	EnvDevelopment = "development"
	EnvStaging     = "staging"
	EnvProduction  = "production"
)

type App struct {
	Name          string `koanf:"app_name"`
	Env           string `koanf:"app_env"`
	Timezone      string `koanf:"app_timezone"`
	PublicBaseURL string `koanf:"app_public_base_url"`
	// Location is Timezone resolved by Load; business dates use it.
	Location *time.Location `koanf:"-"`
}

// IsProduction reports whether APP_ENV is production.
func (a App) IsProduction() bool {
	return a.Env == EnvProduction
}

type HTTP struct {
	Host             string        `koanf:"http_host"`
	Port             int           `koanf:"http_port"`
	ReadTimeout      time.Duration `koanf:"http_read_timeout"`
	WriteTimeout     time.Duration `koanf:"http_write_timeout"`
	IdleTimeout      time.Duration `koanf:"http_idle_timeout"`
	ShutdownTimeout  time.Duration `koanf:"http_shutdown_timeout"`
	BodyLimit        int           `koanf:"http_body_limit"`
	TrustedProxies   []string      `koanf:"http_trusted_proxies"`
	CORSAllowOrigins []string      `koanf:"http_cors_allow_origins"`
}

// Addr is the listen address, e.g. 0.0.0.0:8080.
func (h HTTP) Addr() string {
	return net.JoinHostPort(h.Host, strconv.Itoa(h.Port))
}

type Log struct {
	Level  string `koanf:"log_level"`
	Format string `koanf:"log_format"`
}

type Database struct {
	URL             string        `koanf:"database_url"`
	MaxConns        int32         `koanf:"database_max_conns"`
	MinConns        int32         `koanf:"database_min_conns"`
	MaxConnLifetime time.Duration `koanf:"database_max_conn_lifetime"`
	MaxConnIdleTime time.Duration `koanf:"database_max_conn_idle_time"`
}

type JWT struct {
	Secret     string        `koanf:"jwt_secret"`
	Issuer     string        `koanf:"jwt_issuer"`
	Audience   string        `koanf:"jwt_audience"`
	AccessTTL  time.Duration `koanf:"jwt_access_ttl"`
	RefreshTTL time.Duration `koanf:"jwt_refresh_ttl"`
}

type PIN struct {
	Argon2MemoryKiB   uint32        `koanf:"pin_argon2_memory_kib"`
	Argon2Iterations  uint32        `koanf:"pin_argon2_iterations"`
	Argon2Parallelism uint8         `koanf:"pin_argon2_parallelism"`
	Argon2SaltLength  uint32        `koanf:"pin_argon2_salt_length"`
	Argon2KeyLength   uint32        `koanf:"pin_argon2_key_length"`
	MaxAttempts       int           `koanf:"pin_max_attempts"`
	LockoutDuration   time.Duration `koanf:"pin_lockout_duration"`
}

// Firebase is checked by internal/clients/firebase at startup, which fails
// when the credentials file is missing.
type Firebase struct {
	ProjectID       string `koanf:"firebase_project_id"`
	CredentialsFile string `koanf:"firebase_credentials_file"`
}

type MinIO struct {
	Endpoint string `koanf:"minio_endpoint"`
	// PublicURL is the origin clients reach MinIO at, e.g.
	// https://files.example.com; presigned URLs are signed for it. Empty
	// means Endpoint and UseSSL.
	PublicURL      string        `koanf:"minio_public_url"`
	AccessKey      string        `koanf:"minio_access_key"`
	SecretKey      string        `koanf:"minio_secret_key"`
	UseSSL         bool          `koanf:"minio_use_ssl"`
	Region         string        `koanf:"minio_region"`
	Bucket         string        `koanf:"minio_bucket"`
	PresignTTL     time.Duration `koanf:"minio_presign_ttl"`
	UploadMaxBytes int           `koanf:"upload_max_bytes"`
}

type RateLimit struct {
	OTPMax       int           `koanf:"rate_limit_otp_max"`
	OTPWindow    time.Duration `koanf:"rate_limit_otp_window"`
	PINMax       int           `koanf:"rate_limit_pin_max"`
	PINWindow    time.Duration `koanf:"rate_limit_pin_window"`
	WriteMax     int           `koanf:"rate_limit_write_max"`
	WriteWindow  time.Duration `koanf:"rate_limit_write_window"`
	PublicMax    int           `koanf:"rate_limit_public_max"`
	PublicWindow time.Duration `koanf:"rate_limit_public_window"`
}

// Idempotency TTL sets idempotency_keys.expires_at; the cleanup job deletes
// expired rows, so it is also their retention (DB_SCHEME §10).
type Idempotency struct {
	TTL time.Duration `koanf:"idempotency_ttl"`
}

// Worker holds cmd/worker's settings. The crons are standard five-field
// specs evaluated in APP_TIMEZONE.
type Worker struct {
	MaxWorkers         int    `koanf:"worker_max_workers"`
	ReminderCron       string `koanf:"worker_reminder_cron"`
	MissedAlertCron    string `koanf:"worker_missed_alert_cron"`
	TransferExpiryCron string `koanf:"worker_transfer_expiry_cron"`
	CleanupCron        string `koanf:"worker_cleanup_cron"`
}

type Retention struct {
	RevokedSessions time.Duration `koanf:"retention_revoked_sessions"`
	PaymentProofs   time.Duration `koanf:"retention_payment_proofs"`
}

// defaults are the tunables from .env.example. Secrets and anything that
// differs per deployment (APP_ENV, URLs, endpoints) have no default.
var defaults = map[string]any{
	"app_name":                    "giliran",
	"app_timezone":                "Asia/Jakarta",
	"http_host":                   "0.0.0.0",
	"http_port":                   8080,
	"http_read_timeout":           "10s",
	"http_write_timeout":          "15s",
	"http_idle_timeout":           "60s",
	"http_shutdown_timeout":       "15s",
	"http_body_limit":             6 << 20,
	"log_level":                   "info",
	"log_format":                  "json",
	"database_max_conns":          20,
	"database_min_conns":          2,
	"database_max_conn_lifetime":  "1h",
	"database_max_conn_idle_time": "30m",
	"jwt_issuer":                  "giliran-api",
	"jwt_audience":                "giliran-app",
	"jwt_access_ttl":              "15m",
	"jwt_refresh_ttl":             "720h",
	"pin_argon2_memory_kib":       65536,
	"pin_argon2_iterations":       3,
	"pin_argon2_parallelism":      2,
	"pin_argon2_salt_length":      16,
	"pin_argon2_key_length":       32,
	"pin_max_attempts":            5,
	"pin_lockout_duration":        "15m",
	"firebase_credentials_file":   "./secrets/firebase-service-account.json",
	"minio_use_ssl":               false,
	"minio_region":                "us-east-1",
	"minio_bucket":                "giliran",
	"minio_presign_ttl":           "15m",
	"upload_max_bytes":            5 << 20,
	"rate_limit_otp_max":          5,
	"rate_limit_otp_window":       "15m",
	"rate_limit_pin_max":          10,
	"rate_limit_pin_window":       "15m",
	"rate_limit_write_max":        60,
	"rate_limit_write_window":     "1m",
	"rate_limit_public_max":       30,
	"rate_limit_public_window":    "1m",
	"idempotency_ttl":             "24h",
	"worker_max_workers":          10,
	"worker_reminder_cron":        "0 8 * * *",
	"worker_missed_alert_cron":    "0 10 * * *",
	"worker_transfer_expiry_cron": "0 * * * *",
	"worker_cleanup_cron":         "0 3 * * *",
	"retention_revoked_sessions":  "720h",
	"retention_payment_proofs":    "2160h",
}

// Load reads .env from the working directory, if present, and the process
// environment, then validates the result.
func Load() (*Config, error) {
	return load(".env", os.Environ)
}

// load is Load with the file path and environment injectable for tests.
func load(path string, environ func() []string) (*Config, error) {
	k := koanf.New(".")

	if err := k.Load(confmap.Provider(defaults, "."), nil); err != nil {
		return nil, fmt.Errorf("config: load defaults: %w", err)
	}
	if _, err := os.Stat(path); err == nil {
		if err := k.Load(file.Provider(path), dotenv.ParserEnv("", ".", strings.ToLower)); err != nil {
			return nil, fmt.Errorf("config: load %s: %w", path, err)
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return nil, fmt.Errorf("config: stat %s: %w", path, err)
	}
	envOpt := env.Opt{
		TransformFunc: func(k, v string) (string, any) { return strings.ToLower(k), v },
		EnvironFunc:   environ,
	}
	if err := k.Load(env.Provider(".", envOpt), nil); err != nil {
		return nil, fmt.Errorf("config: load environment: %w", err)
	}

	var cfg Config
	err := k.UnmarshalWithConf("", &cfg, koanf.UnmarshalConf{
		DecoderConfig: &mapstructure.DecoderConfig{
			DecodeHook: mapstructure.ComposeDecodeHookFunc(
				mapstructure.StringToTimeDurationHookFunc(),
				mapstructure.StringToSliceHookFunc(","),
			),
			WeaklyTypedInput: true,
		},
	})
	if err != nil {
		return nil, fmt.Errorf("config: %w", err)
	}
	cfg.HTTP.TrustedProxies = compact(cfg.HTTP.TrustedProxies)
	cfg.HTTP.CORSAllowOrigins = compact(cfg.HTTP.CORSAllowOrigins)

	if err := cfg.validate(); err != nil {
		return nil, fmt.Errorf("config: invalid:\n%w", err)
	}
	cfg.App.Location, _ = time.LoadLocation(cfg.App.Timezone) // validate checked it
	return &cfg, nil
}

// compact trims list entries and drops empty ones, so "" means an empty list.
func compact(in []string) []string {
	out := make([]string, 0, len(in))
	for _, s := range in {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}
