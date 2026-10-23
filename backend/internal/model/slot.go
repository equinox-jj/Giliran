package model

import (
	"time"

	"github.com/google/uuid"
)

// Slot is one arisan "nomor", mirroring the slots table (DB_SCHEME §3.6).
// A slot's win is recorded on Period.WinnerSlotID, not here.
type Slot struct {
	ID                 uuid.UUID `db:"id"`
	GroupID            uuid.UUID `db:"group_id"`
	SlotNo             int16     `db:"slot_no"`              // 1…total_slots, unique per group
	FixedOrderPosition *int16    `db:"fixed_order_position"` // required before start for fixed-order groups
	Label              *string   `db:"label"`
	CreatedAt          time.Time `db:"created_at"`
}

// TableName is the PostgreSQL table that stores slots.
func (Slot) TableName() string {
	return "slots"
}

// HasFixedOrderPosition reports whether the slot has a payout position, which
// fixed-order groups need before they start.
func (s *Slot) HasFixedOrderPosition() bool {
	return s.FixedOrderPosition != nil
}
