package model

import (
	"time"

	"github.com/google/uuid"
)

const (
	// DrawAlgorithmHMACSHA256V1 is the commit-reveal draw in DB_SCHEME §5.
	// Its steps must never change, so published draws stay verifiable.
	DrawAlgorithmHMACSHA256V1 = "hmac-sha256-v1"
	// VerificationCodeLength is the length of a public draw verification code
	// (^[A-Z0-9]{10}$).
	VerificationCodeLength = 10
)

// PeriodStatus is a period's lifecycle state, stored in periods.status
// (DB_SCHEME §4.2).
type PeriodStatus string

const (
	PeriodStatusUpcoming PeriodStatus = "upcoming"
	// PeriodStatusOpen means the seed hash is published and payments exist.
	PeriodStatusOpen   PeriodStatus = "open"
	PeriodStatusDrawn  PeriodStatus = "drawn"
	PeriodStatusClosed PeriodStatus = "closed"
)

// IsValid reports whether s is a known period status (the CHECK constraint).
func (s PeriodStatus) IsValid() bool {
	switch s {
	case PeriodStatusUpcoming, PeriodStatusOpen, PeriodStatusDrawn, PeriodStatusClosed:
		return true
	}
	return false
}

// CanTransitionTo reports whether the state machine allows moving from s to
// next: upcoming opens, open is drawn, drawn closes once the payout is
// recorded. Closed is final.
func (s PeriodStatus) CanTransitionTo(next PeriodStatus) bool {
	switch s {
	case PeriodStatusUpcoming:
		return next == PeriodStatusOpen
	case PeriodStatusOpen:
		return next == PeriodStatusDrawn
	case PeriodStatusDrawn:
		return next == PeriodStatusClosed
	}
	return false
}

// Period is one round of a group, mirroring the periods table (DB_SCHEME §3.8).
// Draw results are immutable once stored.
type Period struct {
	ID               uuid.UUID    `db:"id"`
	GroupID          uuid.UUID    `db:"group_id"`
	PeriodNo         int16        `db:"period_no"` // 1…total_slots
	DueDate          time.Time    `db:"due_date"`  // DATE in Asia/Jakarta
	DrawDate         time.Time    `db:"draw_date"` // DATE in Asia/Jakarta, on or after DueDate
	Status           PeriodStatus `db:"status"`
	SeedHash         *string      `db:"seed_hash"` // hex SHA-256 of the seed, published when the period opens
	Seed             *string      `db:"seed"`      // 32 bytes hex, revealed only with the result
	DrawAlgorithm    string       `db:"draw_algorithm"`
	EligibleSlotIDs  []uuid.UUID  `db:"eligible_slot_ids"` // snapshot at draw time, sorted by slot_no
	WinnerSlotID     *uuid.UUID   `db:"winner_slot_id"`    // unique per group
	VerificationCode *string      `db:"verification_code"` // public code for the Bukti Kocok link
	DrawnAt          *time.Time   `db:"drawn_at"`
	DrawnBy          *uuid.UUID   `db:"drawn_by"`
	CreatedAt        time.Time    `db:"created_at"`
	UpdatedAt        time.Time    `db:"updated_at"`
}

// TableName is the PostgreSQL table that stores periods.
func (Period) TableName() string {
	return "periods"
}

// IsOpen reports whether the period is taking payments.
func (p *Period) IsOpen() bool {
	return p.Status == PeriodStatusOpen
}

// IsDrawn reports whether the period has a winner, which is true for drawn
// and closed periods.
func (p *Period) IsDrawn() bool {
	return p.Status == PeriodStatusDrawn || p.Status == PeriodStatusClosed
}

// HasSeedCommitted reports whether the seed hash has been published. Payments
// in a random group's period can't be approved before this.
func (p *Period) HasSeedCommitted() bool {
	return p.SeedHash != nil
}
