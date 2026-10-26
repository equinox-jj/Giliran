package model

import (
	"time"

	"github.com/google/uuid"
)

// ClaimLinkTTL is how long a guest's claim link stays valid.
const ClaimLinkTTL = 7 * 24 * time.Hour

// MemberRole is a member's role in a group, stored in group_members.role.
type MemberRole string

const (
	// MemberRoleOrganizer is held by exactly one member per group.
	MemberRoleOrganizer MemberRole = "organizer"
	// MemberRoleCoOrganizer is reserved for v2.
	MemberRoleCoOrganizer MemberRole = "co_organizer"
	MemberRoleMember      MemberRole = "member"
)

// IsValid reports whether r is a known role (the CHECK constraint).
func (r MemberRole) IsValid() bool {
	switch r {
	case MemberRoleOrganizer, MemberRoleCoOrganizer, MemberRoleMember:
		return true
	}
	return false
}

// CanManageGroup reports whether the role can perform organizer writes, which
// are recorded in the activity log.
func (r MemberRole) CanManageGroup() bool {
	return r == MemberRoleOrganizer || r == MemberRoleCoOrganizer
}

// MemberStatus is whether a member is still in the group, stored in
// group_members.status.
type MemberStatus string

const (
	MemberStatusActive  MemberStatus = "active"
	MemberStatusLeft    MemberStatus = "left"
	MemberStatusRemoved MemberStatus = "removed"
)

// IsValid reports whether s is a known member status (the CHECK constraint).
func (s MemberStatus) IsValid() bool {
	switch s {
	case MemberStatusActive, MemberStatusLeft, MemberStatusRemoved:
		return true
	}
	return false
}

// GroupMember is a person's membership in one group, mirroring the
// group_members table (DB_SCHEME §3.5). Guests have no UserID and a GuestName
// instead.
type GroupMember struct {
	ID                  uuid.UUID    `db:"id"`
	GroupID             uuid.UUID    `db:"group_id"`
	UserID              *uuid.UUID   `db:"user_id"`     // nil for guests
	GuestName           *string      `db:"guest_name"`  // 2–50 chars; set exactly when UserID is nil
	GuestPhone          *string      `db:"guest_phone"` // E.164, for auto-claim and WhatsApp reminders
	Role                MemberRole   `db:"role"`        // guests are always plain members
	Status              MemberStatus `db:"status"`
	ClaimTokenHash      *string      `db:"claim_token_hash"` // for claim links sent to guests
	ClaimTokenExpiresAt *time.Time   `db:"claim_token_expires_at"`
	JoinedAt            time.Time    `db:"joined_at"`
	LeftAt              *time.Time   `db:"left_at"` // set exactly when the member is no longer active
	CreatedAt           time.Time    `db:"created_at"`
	UpdatedAt           time.Time    `db:"updated_at"`
}

// IsGuest reports whether the member has no account.
func (m *GroupMember) IsGuest() bool {
	return m.UserID == nil
}

// IsActive reports whether the member is still in the group.
func (m *GroupMember) IsActive() bool {
	return m.Status == MemberStatusActive
}

// IsOrganizer reports whether the member is the group's organizer.
func (m *GroupMember) IsOrganizer() bool {
	return m.Role == MemberRoleOrganizer
}
