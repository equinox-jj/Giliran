package model

import (
	"time"

	"github.com/google/uuid"
)

// MaxNoteLength bounds free-text notes and reasons on payments, payouts and
// leave requests.
const MaxNoteLength = 500

// PaymentStatus is a payment's review state, stored in payments.status
// (DB_SCHEME §4.3, BR-07).
type PaymentStatus string

const (
	PaymentStatusUnpaid        PaymentStatus = "unpaid"
	PaymentStatusPendingReview PaymentStatus = "pending_review"
	PaymentStatusPaid          PaymentStatus = "paid"
	PaymentStatusRejected      PaymentStatus = "rejected"
)

// IsValid reports whether s is a known payment status (the CHECK constraint).
func (s PaymentStatus) IsValid() bool {
	switch s {
	case PaymentStatusUnpaid, PaymentStatusPendingReview, PaymentStatusPaid, PaymentStatusRejected:
		return true
	}
	return false
}

// CanTransitionTo reports whether BR-07 allows moving from s to next: unpaid
// gets a proof or is marked paid, pending_review is approved or rejected, and
// rejected gets a new proof. Paid is final. Any other move is
// 409 invalid_payment_state.
func (s PaymentStatus) CanTransitionTo(next PaymentStatus) bool {
	switch s {
	case PaymentStatusUnpaid:
		return next == PaymentStatusPendingReview || next == PaymentStatusPaid
	case PaymentStatusPendingReview:
		return next == PaymentStatusPaid || next == PaymentStatusRejected
	case PaymentStatusRejected:
		return next == PaymentStatusPendingReview
	}
	return false
}

// PaymentMethod is how a payment was made outside the app, stored in
// payments.method.
type PaymentMethod string

const (
	PaymentMethodTransfer PaymentMethod = "transfer"
	PaymentMethodCash     PaymentMethod = "cash"
	PaymentMethodOther    PaymentMethod = "other"
)

// IsValid reports whether m is a known payment method (the CHECK constraint).
func (m PaymentMethod) IsValid() bool {
	switch m {
	case PaymentMethodTransfer, PaymentMethodCash, PaymentMethodOther:
		return true
	}
	return false
}

// Payment is one slot holder's contribution for one period, mirroring the
// payments table (DB_SCHEME §3.9). It records a transfer; it never moves money.
type Payment struct {
	ID             uuid.UUID      `db:"id"`
	GroupID        uuid.UUID      `db:"group_id"` // denormalized for permission checks
	PeriodID       uuid.UUID      `db:"period_id"`
	SlotID         uuid.UUID      `db:"slot_id"`
	MemberID       uuid.UUID      `db:"member_id"`
	Amount         int64          `db:"amount"` // rupiah: group amount × share_pct / 100
	Status         PaymentStatus  `db:"status"`
	Method         *PaymentMethod `db:"method"`
	CurrentProofID *uuid.UUID     `db:"current_proof_id"`
	Note           *string        `db:"note"`          // organizer note when marking paid
	RejectReason   *string        `db:"reject_reason"` // required when rejected
	PaidAt         *time.Time     `db:"paid_at"`       // set exactly when status is paid
	ReviewedBy     *uuid.UUID     `db:"reviewed_by"`
	ReviewedAt     *time.Time     `db:"reviewed_at"`
	CreatedAt      time.Time      `db:"created_at"`
	UpdatedAt      time.Time      `db:"updated_at"`
}

// IsPaid reports whether the payment has been approved or marked paid.
func (p *Payment) IsPaid() bool {
	return p.Status == PaymentStatusPaid
}

// HasProof reports whether a proof screenshot is attached.
func (p *Payment) HasProof() bool {
	return p.CurrentProofID != nil
}
