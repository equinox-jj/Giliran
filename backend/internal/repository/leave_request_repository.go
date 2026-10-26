package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// LeaveRequestRepository reads and writes leave requests.
type LeaveRequestRepository struct {
	tx *TxManager
}

func NewLeaveRequestRepository(tx *TxManager) *LeaveRequestRepository {
	return &LeaveRequestRepository{tx: tx}
}

// Create inserts a pending request; now becomes its created_at. A member
// with a pending request already is ErrDuplicate.
func (r *LeaveRequestRepository) Create(ctx context.Context, req model.LeaveRequest, now time.Time) (model.LeaveRequest, error) {
	row, err := r.tx.Queries(ctx).CreateLeaveRequest(ctx, sqlc.CreateLeaveRequestParams{
		ID: req.ID, GroupID: req.GroupID, MemberID: req.MemberID, Reason: req.Reason, Now: now,
	})
	return toLeaveRequest(row), mapErr(err)
}

// GetForUpdate loads and row-locks a request of groupID. Call it inside
// WithTx.
func (r *LeaveRequestRepository) GetForUpdate(ctx context.Context, groupID, id uuid.UUID) (model.LeaveRequest, error) {
	row, err := r.tx.Queries(ctx).GetLeaveRequestForUpdate(ctx, sqlc.GetLeaveRequestForUpdateParams{ID: id, GroupID: groupID})
	return toLeaveRequest(row), mapErr(err)
}

// List returns the group's requests, newest first. A nil memberID or status
// matches every request.
func (r *LeaveRequestRepository) List(ctx context.Context, groupID uuid.UUID, memberID *uuid.UUID, status *model.LeaveRequestStatus) ([]model.LeaveRequest, error) {
	arg := sqlc.ListLeaveRequestsParams{GroupID: groupID, MemberID: memberID}
	if status != nil {
		s := string(*status)
		arg.Status = &s
	}
	rows, err := r.tx.Queries(ctx).ListLeaveRequests(ctx, arg)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.LeaveRequest, len(rows))
	for i, row := range rows {
		out[i] = toLeaveRequest(row)
	}
	return out, nil
}

// Review records the organizer's decision.
func (r *LeaveRequestRepository) Review(ctx context.Context, id uuid.UUID, status model.LeaveRequestStatus, reviewer uuid.UUID, now time.Time) (model.LeaveRequest, error) {
	row, err := r.tx.Queries(ctx).ReviewLeaveRequest(ctx, sqlc.ReviewLeaveRequestParams{
		ID: id, Status: string(status), ReviewedBy: &reviewer, ReviewedAt: &now,
	})
	return toLeaveRequest(row), mapErr(err)
}

// CancelPending cancels the group's pending requests; a non-nil memberID
// limits it to that member's.
func (r *LeaveRequestRepository) CancelPending(ctx context.Context, groupID uuid.UUID, memberID *uuid.UUID) error {
	return mapErr(r.tx.Queries(ctx).CancelPendingLeaveRequests(ctx, sqlc.CancelPendingLeaveRequestsParams{
		GroupID: groupID, MemberID: memberID,
	}))
}

func toLeaveRequest(row sqlc.LeaveRequest) model.LeaveRequest {
	return model.LeaveRequest{
		ID:         row.ID,
		GroupID:    row.GroupID,
		MemberID:   row.MemberID,
		Reason:     row.Reason,
		Status:     model.LeaveRequestStatus(row.Status),
		ReviewedBy: row.ReviewedBy,
		ReviewedAt: row.ReviewedAt,
		CreatedAt:  row.CreatedAt,
	}
}
