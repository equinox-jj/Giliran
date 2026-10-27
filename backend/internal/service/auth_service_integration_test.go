//go:build integration

package service

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

// identity is a test account: the email it signs in with and the phone it
// then sets on its profile, which reminders use for wa.me links.
type identity struct {
	Email string
	Phone string
}

// accounts maps the keys tests sign in with to identities.
type accounts map[string]identity

var (
	rina     = identity{Email: "rina@gmail.com", Phone: "+6281234567890"}
	budi     = identity{Email: "budi@gmail.com", Phone: "+6281299998888"}
	android  = Device{Name: "Samsung Galaxy A54", Platform: model.DevicePlatformAndroid}
	tokenCfg = &config.Config{JWT: config.JWT{
		Secret: strings.Repeat("s", 32), Issuer: "test", Audience: "test",
		AccessTTL: 15 * time.Minute, RefreshTTL: 30 * 24 * time.Hour,
	}}
	// otpCfg has limits high enough that no fixture trips them.
	otpCfg = config.OTP{
		Secret: strings.Repeat("o", 32), TTL: 10 * time.Minute, ResendInterval: time.Minute,
		LimitPerEmail: 1000, LimitPerIP: 1000, LimitWindow: time.Hour,
	}
)

type authEnv struct {
	svc      *AuthService
	otp      *OTPService
	pins     *PINService
	pool     *pgxpool.Pool
	clock    *clock.Fake
	tokens   *security.TokenIssuer
	accounts accounts
}

func newAuthEnv(t *testing.T, accts accounts) authEnv {
	t.Helper()
	pool := integration.NewDB(t)
	tx := repository.NewTxManager(pool)
	clk := clock.NewFake(time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC))
	cfg := &config.Config{JWT: tokenCfg.JWT, PIN: pinCfg.PIN, OTP: otpCfg}
	tokens := security.NewTokenIssuer(cfg, clk)
	users := repository.NewUserRepository(tx)
	sessions := repository.NewSessionRepository(tx)
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	svc := NewAuthService(tx, sessions, tokens, clk, log, cfg)
	pins := NewPINService(tx, users, security.NewPINHasher(cfg), clk, cfg)
	otp := NewOTPService(tx, users, sessions, repository.NewOTPRepository(tx), pins, svc,
		newTestEnqueuer(t, pool), newMemStore(), clk, log, cfg)
	return authEnv{svc: svc, otp: otp, pins: pins, pool: pool, clock: clk, tokens: tokens, accounts: accts}
}

// code derives the code the email job would send for one send of otpID.
func code(otpID uuid.UUID, resendCount int) string {
	return security.OTPCode([]byte(otpCfg.Secret), otpID, resendCount)
}

// request asks for a code and fails the test on error.
func (e authEnv) request(t *testing.T, in OTPStart) OTPChallenge {
	t.Helper()
	if in.Device == (Device{}) {
		in.Device = android
	}
	ch, err := e.otp.Request(context.Background(), in)
	if err != nil {
		t.Fatalf("Request %s: %v", in.Purpose, err)
	}
	return ch
}

// signInEmail signs in with an emailed code, sending pin for an account that
// has one.
func (e authEnv) signInEmail(t *testing.T, email string, pin *string) SignInResult {
	t.Helper()
	ch := e.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: email})
	res, err := e.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0), PIN: pin}, nil)
	if err != nil {
		t.Fatalf("Verify sign_in: %v", err)
	}
	return *res.Auth
}

// signIn signs the account under key in. A new account also sets its phone,
// as the app would through PATCH /me. Accounts with a PIN must use goodPIN.
func (e authEnv) signIn(t *testing.T, key string) SignInResult {
	t.Helper()
	id, ok := e.accounts[key]
	if !ok {
		t.Fatalf("no test account %q", key)
	}
	pin := goodPIN
	res := e.signInEmail(t, id.Email, &pin)
	if res.IsNewUser && id.Phone != "" {
		if _, err := e.pool.Exec(context.Background(), `UPDATE users SET phone = $2 WHERE id = $1`, res.Profile.User.ID, id.Phone); err != nil {
			t.Fatalf("set phone: %v", err)
		}
		res.Profile.User.Phone = &id.Phone
	}
	return res
}

// caller is the account and session behind res's access token.
func (e authEnv) caller(t *testing.T, res SignInResult) *Caller {
	t.Helper()
	userID, sessionID, err := e.tokens.Parse(res.Tokens.AccessToken)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	return &Caller{UserID: userID, SessionID: sessionID}
}

func (e authEnv) refresh(t *testing.T, token string) TokenPair {
	t.Helper()
	pair, err := e.svc.Refresh(context.Background(), token)
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	return pair
}

// count runs a SELECT count(*) query.
func (e authEnv) count(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	if err := e.pool.QueryRow(context.Background(), sql, args...).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	return n
}

// revokedReason returns the revoke reason of the session for token, or "".
func (e authEnv) revokedReason(t *testing.T, token string) string {
	t.Helper()
	var reason *string
	err := e.pool.QueryRow(context.Background(),
		`SELECT revoked_reason FROM sessions WHERE refresh_token_hash = $1`, security.SHA256Hex([]byte(token))).Scan(&reason)
	if err != nil {
		t.Fatalf("revoked reason: %v", err)
	}
	if reason == nil {
		return ""
	}
	return *reason
}

func TestRefreshRotates(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	signedIn := env.signIn(t, "tok")
	env.clock.Advance(20 * time.Minute)

	// Act
	pair, err := env.svc.Refresh(context.Background(), signedIn.Tokens.RefreshToken)

	// Assert
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if pair.RefreshToken == signedIn.Tokens.RefreshToken {
		t.Error("refresh token was not rotated")
	}
	if got := env.revokedReason(t, signedIn.Tokens.RefreshToken); got != "rotated" {
		t.Errorf("old session revoked_reason %q, want rotated", got)
	}
	_, newSessionID, err := env.tokens.Parse(pair.AccessToken)
	if err != nil {
		t.Fatalf("new access token: %v", err)
	}
	if n := env.count(t, `SELECT count(*) FROM sessions WHERE replaced_by_id = $1`, newSessionID); n != 1 {
		t.Error("old session does not point at the new one")
	}
	if got := env.revokedReason(t, pair.RefreshToken); got != "" {
		t.Errorf("new session revoked (%s)", got)
	}
}

func TestRefreshReuseRevokesFamily(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	stolen := env.signIn(t, "tok").Tokens.RefreshToken
	latest := env.refresh(t, env.refresh(t, stolen).RefreshToken).RefreshToken
	other := env.signIn(t, "tok").Tokens.RefreshToken // another device, another family

	// Act
	_, err := env.svc.Refresh(context.Background(), stolen)

	// Assert
	if !errors.Is(err, model.ErrRefreshTokenInvalid) {
		t.Fatalf("got %v, want refresh_token_invalid", err)
	}
	if got := env.revokedReason(t, latest); got != "reuse_detected" {
		t.Errorf("latest session in the family: revoked_reason %q, want reuse_detected", got)
	}
	if got := env.revokedReason(t, other); got != "" {
		t.Errorf("session in another family revoked (%s)", got)
	}
}

func TestRefreshRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name  string
		token func(t *testing.T, env authEnv) string
	}{
		{"unknown token", func(*testing.T, authEnv) string { return "never-issued" }},
		{"expired", func(t *testing.T, env authEnv) string {
			token := env.signIn(t, "tok").Tokens.RefreshToken
			env.clock.Advance(tokenCfg.JWT.RefreshTTL)
			return token
		}},
		{"logged out", func(t *testing.T, env authEnv) string {
			res := env.signIn(t, "tok")
			_, sessionID, _ := env.tokens.Parse(res.Tokens.AccessToken)
			if err := env.svc.Logout(context.Background(), res.Profile.User.ID, sessionID); err != nil {
				t.Fatalf("Logout: %v", err)
			}
			return res.Tokens.RefreshToken
		}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{"tok": rina})
			token := tt.token(t, env)

			// Act
			_, err := env.svc.Refresh(context.Background(), token)

			// Assert
			if !errors.Is(err, model.ErrRefreshTokenInvalid) {
				t.Errorf("got %v, want refresh_token_invalid", err)
			}
		})
	}
}

func TestLogoutRevokesOnlyCurrentSession(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	current := env.signIn(t, "tok")
	other := env.signIn(t, "tok")
	_, sessionID, err := env.tokens.Parse(current.Tokens.AccessToken)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}

	// Act
	err = env.svc.Logout(context.Background(), current.Profile.User.ID, sessionID)

	// Assert
	if err != nil {
		t.Fatalf("Logout: %v", err)
	}
	if got := env.revokedReason(t, current.Tokens.RefreshToken); got != "logout" {
		t.Errorf("current session revoked_reason %q, want logout", got)
	}
	if got := env.revokedReason(t, other.Tokens.RefreshToken); got != "" {
		t.Errorf("other session revoked (%s)", got)
	}
}

func TestLogoutIgnoresOtherUsersSession(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	victim := env.signIn(t, "tok")
	_, sessionID, _ := env.tokens.Parse(victim.Tokens.AccessToken)

	// Act
	err := env.svc.Logout(context.Background(), uuid.Must(uuid.NewV7()), sessionID)

	// Assert
	if err != nil {
		t.Fatalf("Logout: %v", err)
	}
	if got := env.revokedReason(t, victim.Tokens.RefreshToken); got != "" {
		t.Errorf("another user's session was revoked (%s)", got)
	}
}
