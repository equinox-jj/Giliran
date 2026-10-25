package security

import (
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

const testSecret = "0123456789abcdef0123456789abcdef"

// testNow is the instant the test issuers' clocks are stopped at.
var testNow = time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC)

func testIssuer(secret, issuer, audience string, now time.Time) *TokenIssuer {
	return NewTokenIssuer(&config.Config{JWT: config.JWT{
		Secret:    secret,
		Issuer:    issuer,
		Audience:  audience,
		AccessTTL: 15 * time.Minute,
	}}, clock.NewFake(now))
}

func TestTokenIssuerRoundTrip(t *testing.T) {
	// Arrange
	ti := testIssuer(testSecret, "giliran-api", "giliran-app", testNow)
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	token, expiresAt, err := ti.Issue(userID, sessionID)
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}

	// Act
	gotUser, gotSession, err := ti.Parse(token)

	// Assert
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if gotUser != userID || gotSession != sessionID {
		t.Errorf("got %s/%s, want %s/%s", gotUser, gotSession, userID, sessionID)
	}
	if want := testNow.Add(15 * time.Minute); !expiresAt.Equal(want) {
		t.Errorf("expires at %s, want %s", expiresAt, want)
	}
}

func TestTokenIssuerParseRejects(t *testing.T) {
	// Arrange
	ti := testIssuer(testSecret, "giliran-api", "giliran-app", testNow)
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	issue := func(t *testing.T, from *TokenIssuer) string {
		t.Helper()
		token, _, err := from.Issue(userID, sessionID)
		if err != nil {
			t.Fatalf("Issue: %v", err)
		}
		return token
	}
	sign := func(t *testing.T, method jwt.SigningMethod, key any, claims jwt.Claims) string {
		t.Helper()
		token, err := jwt.NewWithClaims(method, claims).SignedString(key)
		if err != nil {
			t.Fatalf("sign: %v", err)
		}
		return token
	}
	valid := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			Issuer:    "giliran-api",
			Audience:  jwt.ClaimStrings{"giliran-app"},
			ExpiresAt: jwt.NewNumericDate(testNow.Add(time.Minute)),
		},
		SessionID: sessionID.String(),
	}
	noExpiry := valid
	noExpiry.ExpiresAt = nil
	badSubject := valid
	badSubject.Subject = "not-a-uuid"
	badSession := valid
	badSession.SessionID = ""
	tests := []struct {
		name  string
		token func(t *testing.T) string
	}{
		{"expired", func(t *testing.T) string {
			return issue(t, testIssuer(testSecret, "giliran-api", "giliran-app", testNow.Add(-time.Hour)))
		}},
		{"wrong secret", func(t *testing.T) string {
			return issue(t, testIssuer("ffffffffffffffffffffffffffffffff", "giliran-api", "giliran-app", testNow))
		}},
		{"wrong issuer", func(t *testing.T) string { return issue(t, testIssuer(testSecret, "other", "giliran-app", testNow)) }},
		{"wrong audience", func(t *testing.T) string { return issue(t, testIssuer(testSecret, "giliran-api", "other", testNow)) }},
		{"alg none", func(t *testing.T) string {
			return sign(t, jwt.SigningMethodNone, jwt.UnsafeAllowNoneSignatureType, valid)
		}},
		{"HS512", func(t *testing.T) string { return sign(t, jwt.SigningMethodHS512, []byte(testSecret), valid) }},
		{"no expiry", func(t *testing.T) string { return sign(t, jwt.SigningMethodHS256, []byte(testSecret), noExpiry) }},
		{"bad subject", func(t *testing.T) string { return sign(t, jwt.SigningMethodHS256, []byte(testSecret), badSubject) }},
		{"bad session", func(t *testing.T) string { return sign(t, jwt.SigningMethodHS256, []byte(testSecret), badSession) }},
		{"garbage", func(*testing.T) string { return "not.a.jwt" }},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			token := tt.token(t)

			// Act
			_, _, err := ti.Parse(token)

			// Assert
			if !errors.Is(err, model.ErrUnauthorized) {
				t.Errorf("got %v, want unauthorized", err)
			}
		})
	}
}
