package model

import (
	"time"

	"github.com/google/uuid"
)

// SessionTTL is how long a refresh token stays valid after it is issued.
const SessionTTL = 30 * 24 * time.Hour

// DevicePlatform is the OS of a signed-in device, stored in
// sessions.device_platform.
type DevicePlatform string

const (
	DevicePlatformAndroid DevicePlatform = "android"
	DevicePlatformIOS     DevicePlatform = "ios"
)

// IsValid reports whether p is a supported platform (the CHECK constraint).
func (p DevicePlatform) IsValid() bool {
	switch p {
	case DevicePlatformAndroid, DevicePlatformIOS:
		return true
	}
	return false
}

// RevokedReason is why a session was revoked, stored in
// sessions.revoked_reason.
type RevokedReason string

const (
	// RevokedReasonRotated marks a refresh token replaced by its successor.
	RevokedReasonRotated         RevokedReason = "rotated"
	RevokedReasonLogout          RevokedReason = "logout"
	RevokedReasonSignedOutByUser RevokedReason = "signed_out_by_user"
	// RevokedReasonReuseDetected revokes the whole family after a revoked
	// token was presented again.
	RevokedReasonReuseDetected  RevokedReason = "reuse_detected"
	RevokedReasonPINReset       RevokedReason = "pin_reset"
	RevokedReasonPhoneChanged   RevokedReason = "phone_changed"
	RevokedReasonAccountDeleted RevokedReason = "account_deleted"
	RevokedReasonExpired        RevokedReason = "expired"
)

// IsValid reports whether r is a known revoke reason (the CHECK constraint).
func (r RevokedReason) IsValid() bool {
	switch r {
	case RevokedReasonRotated, RevokedReasonLogout, RevokedReasonSignedOutByUser,
		RevokedReasonReuseDetected, RevokedReasonPINReset, RevokedReasonPhoneChanged,
		RevokedReasonAccountDeleted, RevokedReasonExpired:
		return true
	}
	return false
}

// Session is one refresh token, mirroring the sessions table (DB_SCHEME §3.3).
// Rotation creates a new row and revokes the old one.
type Session struct {
	ID               uuid.UUID      `db:"id"`
	UserID           uuid.UUID      `db:"user_id"`
	FamilyID         uuid.UUID      `db:"family_id"`          // same for every rotation of one sign-in
	RefreshTokenHash string         `db:"refresh_token_hash"` // SHA-256 of the token
	ReplacedByID     *uuid.UUID     `db:"replaced_by_id"`     // set on rotation
	DeviceName       *string        `db:"device_name"`
	DevicePlatform   DevicePlatform `db:"device_platform"`
	FCMToken         *string        `db:"fcm_token"`
	LastActiveAt     time.Time      `db:"last_active_at"`
	ExpiresAt        time.Time      `db:"expires_at"`
	RevokedAt        *time.Time     `db:"revoked_at"`
	RevokedReason    *RevokedReason `db:"revoked_reason"` // set together with RevokedAt
	CreatedAt        time.Time      `db:"created_at"`
}

// TableName is the PostgreSQL table that stores sessions.
func (Session) TableName() string {
	return "sessions"
}

// IsRevoked reports whether the session has been revoked.
func (s *Session) IsRevoked() bool {
	return s.RevokedAt != nil
}

// IsExpired reports whether the refresh token has expired at the given time.
func (s *Session) IsExpired(now time.Time) bool {
	return !now.Before(s.ExpiresAt)
}

// IsActive reports whether the refresh token can still be used at the given
// time.
func (s *Session) IsActive(now time.Time) bool {
	return !s.IsRevoked() && !s.IsExpired(now)
}
