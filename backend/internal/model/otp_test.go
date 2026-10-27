package model

import (
	"strconv"
	"testing"
	"time"
)

func TestOTPEnumsIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value interface{ IsValid() bool }
		want  bool
	}{
		{"sign_in", OTPPurposeSignIn, true},
		{"reset_pin", OTPPurposeResetPIN, true},
		{"change_email", OTPPurposeChangeEmail, true},
		{"change_phone", OTPPurpose("change_phone"), false},
		{"pending", OTPStatusPending, true},
		{"consumed", OTPStatusConsumed, true},
		{"expired", OTPStatusExpired, true},
		{"locked", OTPStatusLocked, true},
		{"cancelled", OTPStatusCancelled, true},
		{"matched", OTPStatus("matched"), false},
		{"queued", OTPSendStatusQueued, true},
		{"sent", OTPSendStatusSent, true},
		{"failed", OTPSendStatusFailed, true},
		{"skipped", OTPSendStatusSkipped, true},
		{"bounced", OTPSendStatus("bounced"), false},
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

func TestOTPRequestIsExpired(t *testing.T) {
	// Arrange
	expires := time.Date(2026, 10, 27, 3, 10, 0, 0, time.UTC)
	r := OTPRequest{ExpiresAt: expires}
	tests := []struct {
		name string
		now  time.Time
		want bool
	}{
		{"before expiry", expires.Add(-time.Second), false},
		{"at expiry", expires, true},
		{"after expiry", expires.Add(time.Second), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := r.IsExpired(tt.now)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestOTPRequestIsPending(t *testing.T) {
	// Arrange
	tests := []struct {
		status OTPStatus
		want   bool
	}{
		{OTPStatusPending, true},
		{OTPStatusConsumed, false},
		{OTPStatusExpired, false},
		{OTPStatusLocked, false},
		{OTPStatusCancelled, false},
	}

	for _, tt := range tests {
		t.Run(string(tt.status), func(t *testing.T) {
			r := OTPRequest{Status: tt.status}

			// Act
			got := r.IsPending()

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestOTPRequestAttemptsRemaining(t *testing.T) {
	// Arrange
	tests := []struct {
		attempts int16
		want     int
	}{
		{0, 5},
		{3, 2},
		{5, 0},
	}

	for _, tt := range tests {
		t.Run(strconv.Itoa(int(tt.attempts)), func(t *testing.T) {
			r := OTPRequest{Attempts: tt.attempts}

			// Act
			got := r.AttemptsRemaining()

			// Assert
			if got != tt.want {
				t.Errorf("got %d, want %d", got, tt.want)
			}
		})
	}
}

func TestOTPRequestResendAvailableAt(t *testing.T) {
	// Arrange
	sent := time.Date(2026, 10, 27, 3, 0, 0, 0, time.UTC)
	r := OTPRequest{LastSentAt: sent}

	// Act
	got := r.ResendAvailableAt(time.Minute)

	// Assert
	if want := sent.Add(time.Minute); !got.Equal(want) {
		t.Errorf("got %v, want %v", got, want)
	}
}
