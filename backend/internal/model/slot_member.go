package model

import (
	"time"

	"github.com/google/uuid"
)

// FullShareBasisPoints is a 100% share of a slot in basis points
// (share_pct 100.00).
const FullShareBasisPoints = 10_000

// SlotMember links a member to a slot, mirroring the slot_members table
// (DB_SCHEME §3.7). The MVP always uses a full share; v2 shared slots split it.
type SlotMember struct {
	SlotID   uuid.UUID `db:"slot_id"`
	MemberID uuid.UUID `db:"member_id"`
	// SharePctBasisPoints is share_pct numeric(5,2) times 100 (100.00 → 10_000),
	// so money math stays in integers. The repository converts the numeric.
	SharePctBasisPoints int32     `db:"share_pct"`
	CreatedAt           time.Time `db:"created_at"`
}

// TableName is the PostgreSQL table that stores slot members.
func (SlotMember) TableName() string {
	return "slot_members"
}

// NewSlotMember returns a full-share link, the table default.
func NewSlotMember(slotID, memberID uuid.UUID) SlotMember {
	return SlotMember{
		SlotID:              slotID,
		MemberID:            memberID,
		SharePctBasisPoints: FullShareBasisPoints,
	}
}

// ShareOf returns this member's part of a slot's contribution in rupiah
// (amount × share_pct / 100), rounded down.
func (sm *SlotMember) ShareOf(amount int64) int64 {
	return amount * int64(sm.SharePctBasisPoints) / FullShareBasisPoints
}
