package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// ActorType is who wrote an activity log entry, stored in
// activity_logs.actor_type.
type ActorType string

const (
	ActorTypeUser ActorType = "user"
	// ActorTypeSystem marks entries written by background jobs.
	ActorTypeSystem ActorType = "system"
)

// IsValid reports whether a is a known actor type (the CHECK constraint).
func (a ActorType) IsValid() bool {
	switch a {
	case ActorTypeUser, ActorTypeSystem:
		return true
	}
	return false
}

// EntityType is the kind of row an activity log entry is about, stored in
// activity_logs.entity_type.
type EntityType string

const (
	EntityTypeGroup   EntityType = "group"
	EntityTypeMember  EntityType = "member"
	EntityTypePeriod  EntityType = "period"
	EntityTypePayment EntityType = "payment"
	EntityTypePayout  EntityType = "payout"
)

// Action is what happened, stored in activity_logs.action as
// "<entity>.<verb>" (DB_SCHEME §7).
type Action string

const (
	ActionGroupCreated            Action = "group.created"
	ActionGroupUpdated            Action = "group.updated"
	ActionGroupPaymentInfoUpdated Action = "group.payment_info_updated"
	ActionGroupStarted            Action = "group.started"
	ActionGroupClosed             Action = "group.closed"
	ActionMemberJoined            Action = "member.joined"
	ActionMemberGuestAdded        Action = "member.guest_added"
	ActionMemberGuestClaimed      Action = "member.guest_claimed"
	ActionMemberRemoved           Action = "member.removed"
	ActionMemberLeft              Action = "member.left"
	ActionPeriodOpened            Action = "period.opened"
	ActionPaymentProofUploaded    Action = "payment.proof_uploaded"
	ActionPaymentApproved         Action = "payment.approved"
	ActionPaymentRejected         Action = "payment.rejected"
	ActionPaymentMarkedPaid       Action = "payment.marked_paid"
	ActionDrawCompleted           Action = "draw.completed"
	ActionPayoutRecorded          Action = "payout.recorded"
	ActionPayoutConfirmed         Action = "payout.confirmed"
	ActionOwnershipTransferred    Action = "ownership.transferred"
)

// ActivityLog is one entry in a group's audit trail, mirroring the
// activity_logs table (DB_SCHEME §3.14). Entries are append-only; corrections
// are new entries.
type ActivityLog struct {
	ID          int64           `db:"id"` // identity; the pagination cursor
	GroupID     uuid.UUID       `db:"group_id"`
	ActorType   ActorType       `db:"actor_type"`
	ActorUserID *uuid.UUID      `db:"actor_user_id"` // nil for system entries
	Action      Action          `db:"action"`
	EntityType  EntityType      `db:"entity_type"`
	EntityID    *uuid.UUID      `db:"entity_id"`
	Before      json.RawMessage `db:"before"` // changed fields before
	After       json.RawMessage `db:"after"`  // changed fields after
	CreatedAt   time.Time       `db:"created_at"`
}

// IsSystem reports whether a background job wrote the entry.
func (l *ActivityLog) IsSystem() bool {
	return l.ActorType == ActorTypeSystem
}
