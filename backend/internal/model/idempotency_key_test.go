package model

import (
	"testing"
	"time"
)

func TestIdempotencyKeyIsExpired(t *testing.T) {
	// Arrange
	expiresAt := time.Date(2026, 10, 25, 0, 0, 0, 0, time.UTC)
	tests := []struct {
		name string
		now  time.Time
		want bool
	}{
		{"before expiry", expiresAt.Add(-time.Second), false},
		{"at expiry", expiresAt, true},
		{"after expiry", expiresAt.Add(time.Second), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			key := IdempotencyKey{ExpiresAt: expiresAt}

			// Act
			got := key.IsExpired(tt.now)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIdempotencyKeyMatchesRequest(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		hash string
		want bool
	}{
		{"same body", "abc123", true},
		{"different body", "def456", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			key := IdempotencyKey{RequestHash: "abc123"}

			// Act
			got := key.MatchesRequest(tt.hash)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
