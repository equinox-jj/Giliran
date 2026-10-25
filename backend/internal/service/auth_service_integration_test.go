//go:build integration

package service

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

// fakeVerifier maps ID tokens to identities; unknown tokens are rejected.
type fakeVerifier map[string]firebase.Identity

func (f fakeVerifier) Verify(_ context.Context, idToken string) (firebase.Identity, error) {
	id, ok := f[idToken]
	if !ok {
		return firebase.Identity{}, model.ErrOTPInvalid
	}
	return id, nil
}

var (
	rina     = firebase.Identity{UID: "uid-rina", Phone: "+6281234567890"}
	android  = Device{Name: "Samsung Galaxy A54", Platform: model.DevicePlatformAndroid}
	tokenCfg = &config.Config{JWT: config.JWT{
		Secret: strings.Repeat("s", 32), Issuer: "test", Audience: "test",
		AccessTTL: 15 * time.Minute, RefreshTTL: 30 * 24 * time.Hour,
	}}
)

type authEnv struct {
	svc    *AuthService
	pool   *pgxpool.Pool
	clock  *clock.Fake
	tokens *security.TokenIssuer
}

func newAuthEnv(t *testing.T, verifier fakeVerifier) authEnv {
	t.Helper()
	pool := integration.NewDB(t)
	tx := repository.NewTxManager(pool)
	clk := clock.NewFake(time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC))
	tokens := security.NewTokenIssuer(tokenCfg, clk)
	svc := NewAuthService(tx, repository.NewUserRepository(tx), repository.NewSessionRepository(tx),
		verifier, tokens, clk, slog.New(slog.NewTextHandler(io.Discard, nil)), tokenCfg)
	return authEnv{svc: svc, pool: pool, clock: clk, tokens: tokens}
}

func (e authEnv) signIn(t *testing.T, idToken string) SignInResult {
	t.Helper()
	res, err := e.svc.SignIn(context.Background(), idToken, android)
	if err != nil {
		t.Fatalf("SignIn: %v", err)
	}
	return res
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

func TestSignInCreatesAccount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, fakeVerifier{"tok": rina})

	// Act
	res := env.signIn(t, "tok")

	// Assert
	if !res.IsNewUser || res.User.Phone != rina.Phone || res.User.HasPIN() {
		t.Errorf("result %+v", res)
	}
	if n := env.count(t, `SELECT count(*) FROM user_settings WHERE user_id = $1`, res.User.ID); n != 1 {
		t.Errorf("%d settings rows, want 1", n)
	}
	userID, sessionID, err := env.tokens.Parse(res.Tokens.AccessToken)
	if err != nil || userID != res.User.ID {
		t.Fatalf("access token: %v, user %s", err, userID)
	}
	if n := env.count(t, `SELECT count(*) FROM sessions WHERE id = $1 AND user_id = $2 AND device_name = $3 AND revoked_at IS NULL`,
		sessionID, userID, android.Name); n != 1 {
		t.Error("session row missing or wrong")
	}
	if res.Tokens.ExpiresIn != 15*time.Minute || res.Tokens.RefreshToken == "" {
		t.Errorf("tokens %+v", res.Tokens)
	}
}

func TestSignInReturningUser(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, fakeVerifier{"tok": rina})
	first := env.signIn(t, "tok")

	// Act
	second := env.signIn(t, "tok")

	// Assert
	if second.IsNewUser || second.User.ID != first.User.ID {
		t.Errorf("second sign-in: new %v, user %s, want existing %s", second.IsNewUser, second.User.ID, first.User.ID)
	}
	if n := env.count(t, `SELECT count(DISTINCT family_id) FROM sessions WHERE user_id = $1`, first.User.ID); n != 2 {
		t.Errorf("%d session families, want 2 (one per sign-in)", n)
	}
}

func TestSignInLinksNewFirebaseUIDToKnownPhone(t *testing.T) {
	// Arrange
	t.Parallel()
	reissued := firebase.Identity{UID: "uid-rina-new", Phone: rina.Phone}
	env := newAuthEnv(t, fakeVerifier{"old": rina, "new": reissued})
	first := env.signIn(t, "old")

	// Act
	second := env.signIn(t, "new")

	// Assert
	if second.IsNewUser || second.User.ID != first.User.ID {
		t.Fatalf("got user %s (new %v), want %s", second.User.ID, second.IsNewUser, first.User.ID)
	}
	if second.User.FirebaseUID == nil || *second.User.FirebaseUID != reissued.UID {
		t.Errorf("firebase uid %v, want %s", second.User.FirebaseUID, reissued.UID)
	}
}

func TestSignInRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, fakeVerifier{"foreign": {UID: "uid-sg", Phone: "+6591234567"}})
	tests := []struct {
		name  string
		token string
	}{
		{"token the verifier rejects", "unknown"},
		{"non-Indonesian number", "foreign"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := env.svc.SignIn(context.Background(), tt.token, android)

			// Assert
			if !errors.Is(err, model.ErrOTPInvalid) {
				t.Errorf("got %v, want otp_invalid", err)
			}
		})
	}
}

func TestSignInConcurrentFirstSignIn(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, fakeVerifier{"tok": rina})
	const n = 5
	results := make([]SignInResult, n)
	errs := make([]error, n)
	var wg sync.WaitGroup

	// Act
	for i := range n {
		wg.Go(func() { results[i], errs[i] = env.svc.SignIn(context.Background(), "tok", android) })
	}
	wg.Wait()

	// Assert
	for i, err := range errs {
		if err != nil {
			t.Fatalf("sign-in %d: %v", i, err)
		}
		if results[i].User.ID != results[0].User.ID {
			t.Errorf("sign-in %d got user %s, want %s", i, results[i].User.ID, results[0].User.ID)
		}
	}
	if users := env.count(t, `SELECT count(*) FROM users`); users != 1 {
		t.Errorf("%d users, want 1", users)
	}
}

func TestRefreshRotates(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, fakeVerifier{"tok": rina})
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
	env := newAuthEnv(t, fakeVerifier{"tok": rina})
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
			if err := env.svc.Logout(context.Background(), res.User.ID, sessionID); err != nil {
				t.Fatalf("Logout: %v", err)
			}
			return res.Tokens.RefreshToken
		}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, fakeVerifier{"tok": rina})
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
	env := newAuthEnv(t, fakeVerifier{"tok": rina})
	current := env.signIn(t, "tok")
	other := env.signIn(t, "tok")
	_, sessionID, err := env.tokens.Parse(current.Tokens.AccessToken)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}

	// Act
	err = env.svc.Logout(context.Background(), current.User.ID, sessionID)

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
	env := newAuthEnv(t, fakeVerifier{"tok": rina})
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
