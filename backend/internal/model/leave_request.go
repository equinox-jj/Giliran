package model

import (
	"time"

	"github.com/google/uuid"
)

// LeaveRequestStatus is a leave request's state, stored in
// leave_requests.status.
type LeaveRequestStatus string

const (
	LeaveRequestStatusPending   LeaveRequestStatus = "pending"
	LeaveRequestStatusApproved  LeaveRequestStatus = "approved"
	LeaveRequestStatusRejected  LeaveRequestStatus = "rejected"
	LeaveRequestStatusCancelled LeaveRequestStatus = "cancelled"
)

// IsValid reports whether s is a known leave request status (the CHECK
// constraint).
func (s LeaveRequestStatus) IsValid() bool {
	switch s {
	case LeaveRequestStatusPending, LeaveRequestStatusApproved,
		LeaveRequestStatusRejected, LeaveRequestStatusCancelled:
		return true
	}
	return false
}

// CanTransitionTo reports whether a request can move from s to next: a pending
// request is approved, rejected or cancelled. Every other status is final.
func (s LeaveRequestStatus) CanTransitionTo(next LeaveRequestStatus) bool {
	if s != LeaveRequestStatusPending {
		return false
	}
	switch next {
	case LeaveRequestStatusApproved, LeaveRequestStatusRejected, LeaveRequestStatusCancelled:
		return true
	}
	return false
}

// LeaveRequest is a member asking to leave a group, mirroring the
// leave_requests table (DB_SCHEME §3.12). A member has at most one pending
// request.
type LeaveRequest struct {
	ID         uuid.UUID          `db:"id"`
	GroupID    uuid.UUID          `db:"group_id"`
	MemberID   uuid.UUID          `db:"member_id"`
	Reason     *string            `db:"reason"` // at most MaxNoteLength chars
	Status     LeaveRequestStatus `db:"status"`
	ReviewedBy *uuid.UUID         `db:"reviewed_by"`
	ReviewedAt *time.Time         `db:"reviewed_at"`
	CreatedAt  time.Time          `db:"created_at"`
}

// TableName is the PostgreSQL table that stores leave requests.
func (LeaveRequest) TableName() string {
	return "leave_requests"
}

// IsPending reports whether the request is waiting for the organizer.
func (r *LeaveRequest) IsPending() bool {
	return r.Status == LeaveRequestStatusPending
}
