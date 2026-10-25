package security

import (
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

const testSecret = "0123456789abcdef0123456789abcdef"

func testIssuer(secret, issuer, audience string) *TokenIssuer {
	return NewTokenIssuer(&config.Config{JWT: config.JWT{
		Secret:    secret,
		Issuer:    issuer,
		Audience:  audience,
		AccessTTL: 15 * time.Minute,
	}})
}

func TestTokenIssuerRoundTrip(t *testing.T) {
	// Arrange
	ti := testIssuer(testSecret, "giliran-api", "giliran-app")
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	token, expiresAt, err := ti.Issue(userID, sessionID, time.Now())
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
	if d := time.Until(expiresAt); d <= 14*time.Minute || d > 15*time.Minute {
		t.Errorf("expires in %s, want about 15m", d)
	}
}

func TestTokenIssuerParseRejects(t *testing.T) {
	// Arrange
	ti := testIssuer(testSecret, "giliran-api", "giliran-app")
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	issue := func(t *testing.T, from *TokenIssuer, now time.Time) string {
		t.Helper()
		token, _, err := from.Issue(userID, sessionID, now)
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
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Minute)),
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
		{"expired", func(t *testing.T) string { return issue(t, ti, time.Now().Add(-time.Hour)) }},
		{"wrong secret", func(t *testing.T) string {
			return issue(t, testIssuer("ffffffffffffffffffffffffffffffff", "giliran-api", "giliran-app"), time.Now())
		}},
		{"wrong issuer", func(t *testing.T) string { return issue(t, testIssuer(testSecret, "other", "giliran-app"), time.Now()) }},
		{"wrong audience", func(t *testing.T) string { return issue(t, testIssuer(testSecret, "giliran-api", "other"), time.Now()) }},
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
