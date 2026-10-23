package model

import (
	"time"

	"github.com/google/uuid"
)

const (
	MinGroupNameLength = 3
	MaxGroupNameLength = 60
	// MinGroupAmount and MaxGroupAmount bound the contribution per slot per
	// period, in rupiah.
	MinGroupAmount int64 = 10_000
	MaxGroupAmount int64 = 100_000_000
	MinGroupSlots        = 2
	MaxGroupSlots        = 50
	// DefaultReminderDaysBefore is how many days before the due date the
	// payment reminder goes out unless the organizer changes it.
	DefaultReminderDaysBefore = 2
	MaxReminderDaysBefore     = 7
	// InviteCodeLength is the length of an invite code (^[A-Z0-9]{8}$).
	InviteCodeLength = 8
)

// PeriodType is how often a group's periods repeat, stored in groups.period_type.
type PeriodType string

const (
	PeriodTypeWeekly  PeriodType = "weekly"
	PeriodTypeMonthly PeriodType = "monthly"
)

// IsValid reports whether p is a supported period type (the CHECK constraint).
func (p PeriodType) IsValid() bool {
	switch p {
	case PeriodTypeWeekly, PeriodTypeMonthly:
		return true
	}
	return false
}

// DrawMethod is how each period's winner is chosen, stored in groups.draw_method.
type DrawMethod string

const (
	// DrawMethodRandom uses the commit-reveal hmac-sha256-v1 draw (DB_SCHEME §5).
	DrawMethodRandom DrawMethod = "random"
	// DrawMethodFixedOrder pays slots out by fixed_order_position, with no seed.
	DrawMethodFixedOrder DrawMethod = "fixed_order"
)

// IsValid reports whether m is a supported draw method (the CHECK constraint).
func (m DrawMethod) IsValid() bool {
	switch m {
	case DrawMethodRandom, DrawMethodFixedOrder:
		return true
	}
	return false
}

// GroupStatus is a group's lifecycle state, stored in groups.status
// (DB_SCHEME §4.1).
type GroupStatus string

const (
	GroupStatusDraft     GroupStatus = "draft"
	GroupStatusActive    GroupStatus = "active"
	GroupStatusCompleted GroupStatus = "completed"
	GroupStatusClosed    GroupStatus = "closed"
)

// IsValid reports whether s is a known group status (the CHECK constraint).
func (s GroupStatus) IsValid() bool {
	switch s {
	case GroupStatusDraft, GroupStatusActive, GroupStatusCompleted, GroupStatusClosed:
		return true
	}
	return false
}

// CanTransitionTo reports whether the state machine allows moving from s to
// next: draft starts or closes, active completes or closes. Completed and
// closed are final.
func (s GroupStatus) CanTransitionTo(next GroupStatus) bool {
	switch s {
	case GroupStatusDraft:
		return next == GroupStatusActive || next == GroupStatusClosed
	case GroupStatusActive:
		return next == GroupStatusCompleted || next == GroupStatusClosed
	}
	return false
}

// Group is one arisan, mirroring the groups table (DB_SCHEME §3.4).
// Groups are closed, never deleted.
type Group struct {
	ID                 uuid.UUID   `db:"id"`
	OrganizerID        uuid.UUID   `db:"organizer_id"` // kept in sync with the organizer member row
	Name               string      `db:"name"`         // 3–60 chars
	Amount             int64       `db:"amount"`       // rupiah per slot per period
	PeriodType         PeriodType  `db:"period_type"`
	TotalSlots         int16       `db:"total_slots"` // equals the number of periods
	DrawMethod         DrawMethod  `db:"draw_method"`
	StartDate          time.Time   `db:"start_date"` // DATE in Asia/Jakarta: the first period's due date
	ReminderDaysBefore int16       `db:"reminder_days_before"`
	Status             GroupStatus `db:"status"`
	InviteCode         string      `db:"invite_code"` // 8 chars, unique, resettable
	BankName           *string     `db:"bank_name"`
	BankAccountNumber  *string     `db:"bank_account_number"` // visible to group members only
	BankAccountHolder  *string     `db:"bank_account_holder"`
	QRISPayload        *string     `db:"qris_payload"`   // decoded EMV string, TLV + CRC-16 validated
	QRISImageKey       *string     `db:"qris_image_key"` // MinIO object key
	StartedAt          *time.Time  `db:"started_at"`     // when period 1 opened
	CompletedAt        *time.Time  `db:"completed_at"`   // when the last period closed
	ClosedAt           *time.Time  `db:"closed_at"`      // closed early by the organizer
	CreatedAt          time.Time   `db:"created_at"`
	UpdatedAt          time.Time   `db:"updated_at"`
}

// TableName is the PostgreSQL table that stores groups.
func (Group) TableName() string {
	return "groups"
}

// IsDraft reports whether the group is still taking members and editable.
func (g *Group) IsDraft() bool {
	return g.Status == GroupStatusDraft
}

// IsActive reports whether the group's periods are running.
func (g *Group) IsActive() bool {
	return g.Status == GroupStatusActive
}

// IsSettingsLocked reports whether amount, period type and slots can no longer
// change, which is the case once the group leaves draft.
func (g *Group) IsSettingsLocked() bool {
	return g.Status != GroupStatusDraft
}

// IsFinished reports whether the group has completed or been closed.
func (g *Group) IsFinished() bool {
	return g.Status == GroupStatusCompleted || g.Status == GroupStatusClosed
}

// UsesSeed reports whether draws use the commit-reveal seed. Fixed-order
// groups skip it.
func (g *Group) UsesSeed() bool {
	return g.DrawMethod == DrawMethodRandom
}

// HasBankAccount reports whether the organizer has set a bank account for
// payments.
func (g *Group) HasBankAccount() bool {
	return g.BankAccountNumber != nil
}

// HasQRIS reports whether the organizer has set a QRIS code for payments.
func (g *Group) HasQRIS() bool {
	return g.QRISPayload != nil
}

// TotalPot returns the rupiah one period's winner receives: every slot's
// contribution.
func (g *Group) TotalPot() int64 {
	return g.Amount * int64(g.TotalSlots)
}
