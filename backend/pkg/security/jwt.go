package security

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Claims are the access token claims: sub is the user ID, sid the session ID.
type Claims struct {
	jwt.RegisteredClaims
	SessionID string `json:"sid"`
}

// TokenIssuer issues and parses HS256 access tokens. Access tokens are
// stateless; revocation happens on the refresh token (FR-AUTH-07).
type TokenIssuer struct {
	secret   []byte
	issuer   string
	audience string
	ttl      time.Duration
	parser   *jwt.Parser
}

// NewTokenIssuer builds a TokenIssuer from the JWT_* settings.
func NewTokenIssuer(cfg *config.Config) *TokenIssuer {
	j := cfg.JWT
	return &TokenIssuer{
		secret:   []byte(j.Secret),
		issuer:   j.Issuer,
		audience: j.Audience,
		ttl:      j.AccessTTL,
		parser: jwt.NewParser(
			jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
			jwt.WithIssuer(j.Issuer),
			jwt.WithAudience(j.Audience),
			jwt.WithExpirationRequired(),
			jwt.WithIssuedAt(),
		),
	}
}

// TTL is the access token lifetime, for the expires_in response field.
func (t *TokenIssuer) TTL() time.Duration {
	return t.ttl
}

// Issue signs an access token for the user's session, valid from now.
func (t *TokenIssuer) Issue(userID, sessionID uuid.UUID, now time.Time) (string, time.Time, error) {
	jti, err := uuid.NewV7()
	if err != nil {
		return "", time.Time{}, fmt.Errorf("security: token id: %w", err)
	}
	expiresAt := now.Add(t.ttl)
	claims := Claims{
		ID:        jti.String(),
		Subject:   userID.String(),
		Issuer:    t.issuer,
		Audience:  jwt.ClaimStrings{t.audience},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(expiresAt),
		SessionID: sessionID.String(),
	}
	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(t.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("security: sign token: %w", err)
	}
	return signed, expiresAt, nil
}

// Parse verifies token and returns its user and session IDs. Any failure,
// including expiry, is model.ErrUnauthorized.
func (t *TokenIssuer) Parse(token string) (userID, sessionID uuid.UUID, err error) {
	var claims Claims
	if _, err := t.parser.ParseWithClaims(token, &claims, func(*jwt.Token) (any, error) {
		return t.secret, nil
	}); err != nil {
		return uuid.Nil, uuid.Nil, model.ErrUnauthorized
	}
	userID, err = uuid.Parse(claims.Subject)
	if err != nil {
		return uuid.Nil, uuid.Nil, model.ErrUnauthorized
	}
	sessionID, err = uuid.Parse(claims.SessionID)
	if err != nil {
		return uuid.Nil, uuid.Nil, model.ErrUnauthorized
	}
	return userID, sessionID, nil
}
