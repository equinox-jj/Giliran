package model

import (
	"testing"
	"time"
)

func TestSessionIsActive(t *testing.T) {
	// Arrange
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	revokedAt := now.Add(-time.Hour)
	tests := []struct {
		name    string
		session Session
		want    bool
	}{
		{"active", Session{ExpiresAt: now.Add(time.Hour)}, true},
		{"revoked", Session{ExpiresAt: now.Add(time.Hour), RevokedAt: &revokedAt}, false},
		{"expired", Session{ExpiresAt: now}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := tt.session.IsActive(now)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSessionEnumsIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value interface{ IsValid() bool }
		want  bool
	}{
		{"android", DevicePlatformAndroid, true},
		{"ios", DevicePlatformIOS, true},
		{"web", DevicePlatform("web"), false},
		{"rotated", RevokedReasonRotated, true},
		{"logout", RevokedReasonLogout, true},
		{"signed_out_by_user", RevokedReasonSignedOutByUser, true},
		{"reuse_detected", RevokedReasonReuseDetected, true},
		{"pin_reset", RevokedReasonPINReset, true},
		{"email_changed", RevokedReasonEmailChanged, true},
		{"phone_changed", RevokedReason("phone_changed"), false},
		{"account_deleted", RevokedReasonAccountDeleted, true},
		{"expired", RevokedReasonExpired, true},
		{"banned", RevokedReason("banned"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := tt.value.IsValid()

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
