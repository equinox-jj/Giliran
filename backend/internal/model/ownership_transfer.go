package model

import (
	"time"

	"github.com/google/uuid"
)

// OwnershipTransferTTL is how long the new organizer has to respond.
const OwnershipTransferTTL = 7 * 24 * time.Hour

// OwnershipTransferStatus is a transfer's state, stored in
// ownership_transfers.status.
type OwnershipTransferStatus string

const (
	OwnershipTransferStatusPending   OwnershipTransferStatus = "pending"
	OwnershipTransferStatusAccepted  OwnershipTransferStatus = "accepted"
	OwnershipTransferStatusDeclined  OwnershipTransferStatus = "declined"
	OwnershipTransferStatusCancelled OwnershipTransferStatus = "cancelled"
	OwnershipTransferStatusExpired   OwnershipTransferStatus = "expired"
)

// IsValid reports whether s is a known transfer status (the CHECK constraint).
func (s OwnershipTransferStatus) IsValid() bool {
	switch s {
	case OwnershipTransferStatusPending, OwnershipTransferStatusAccepted,
		OwnershipTransferStatusDeclined, OwnershipTransferStatusCancelled,
		OwnershipTransferStatusExpired:
		return true
	}
	return false
}

// CanTransitionTo reports whether a transfer can move from s to next: a
// pending transfer is accepted, declined, cancelled or expires. Every other
// status is final.
func (s OwnershipTransferStatus) CanTransitionTo(next OwnershipTransferStatus) bool {
	if s != OwnershipTransferStatusPending {
		return false
	}
	switch next {
	case OwnershipTransferStatusAccepted, OwnershipTransferStatusDeclined,
		OwnershipTransferStatusCancelled, OwnershipTransferStatusExpired:
		return true
	}
	return false
}

// OwnershipTransfer is an organizer handing a group to another member,
// mirroring the ownership_transfers table (DB_SCHEME §3.13). A group has at
// most one pending transfer.
type OwnershipTransfer struct {
	ID          uuid.UUID               `db:"id"`
	GroupID     uuid.UUID               `db:"group_id"`
	FromUserID  uuid.UUID               `db:"from_user_id"`
	ToMemberID  uuid.UUID               `db:"to_member_id"` // must have an account
	Status      OwnershipTransferStatus `db:"status"`
	ExpiresAt   time.Time               `db:"expires_at"`
	RespondedAt *time.Time              `db:"responded_at"`
	CreatedAt   time.Time               `db:"created_at"`
}

// TableName is the PostgreSQL table that stores ownership transfers.
func (OwnershipTransfer) TableName() string {
	return "ownership_transfers"
}

// IsPending reports whether the transfer is waiting for a response.
func (t *OwnershipTransfer) IsPending() bool {
	return t.Status == OwnershipTransferStatusPending
}

// IsExpired reports whether the response window has passed at the given time.
func (t *OwnershipTransfer) IsExpired(now time.Time) bool {
	return !now.Before(t.ExpiresAt)
}
