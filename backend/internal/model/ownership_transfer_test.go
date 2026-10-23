package model

import (
	"testing"
	"time"
)

func TestOwnershipTransferStatusCanTransitionTo(t *testing.T) {
	// Arrange
	allowed := map[[2]OwnershipTransferStatus]bool{
		{OwnershipTransferStatusPending, OwnershipTransferStatusAccepted}:  true,
		{OwnershipTransferStatusPending, OwnershipTransferStatusDeclined}:  true,
		{OwnershipTransferStatusPending, OwnershipTransferStatusCancelled}: true,
		{OwnershipTransferStatusPending, OwnershipTransferStatusExpired}:   true,
	}
	statuses := []OwnershipTransferStatus{
		OwnershipTransferStatusPending, OwnershipTransferStatusAccepted,
		OwnershipTransferStatusDeclined, OwnershipTransferStatusCancelled,
		OwnershipTransferStatusExpired,
	}

	for _, from := range statuses {
		for _, to := range statuses {
			want := allowed[[2]OwnershipTransferStatus{from, to}]

			t.Run(string(from)+"->"+string(to), func(t *testing.T) {
				// Act
				got := from.CanTransitionTo(to)

				// Assert
				if got != want {
					t.Errorf("got %v, want %v", got, want)
				}
			})
		}
	}
}

func TestOwnershipTransferStatusIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value OwnershipTransferStatus
		want  bool
	}{
		{"pending", OwnershipTransferStatusPending, true},
		{"accepted", OwnershipTransferStatusAccepted, true},
		{"declined", OwnershipTransferStatusDeclined, true},
		{"cancelled", OwnershipTransferStatusCancelled, true},
		{"expired", OwnershipTransferStatusExpired, true},
		{"revoked", OwnershipTransferStatus("revoked"), false},
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

func TestOwnershipTransferIsExpired(t *testing.T) {
	// Arrange
	expiresAt := time.Date(2026, 10, 31, 0, 0, 0, 0, time.UTC)
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
			transfer := OwnershipTransfer{ExpiresAt: expiresAt}

			// Act
			got := transfer.IsExpired(tt.now)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
