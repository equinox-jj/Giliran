package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// OwnershipTransferRepository reads and writes ownership transfers.
type OwnershipTransferRepository struct {
	tx *TxManager
}

func NewOwnershipTransferRepository(tx *TxManager) *OwnershipTransferRepository {
	return &OwnershipTransferRepository{tx: tx}
}

// Create inserts a pending transfer; now becomes its created_at. A group with
// a pending transfer already is ErrDuplicate.
func (r *OwnershipTransferRepository) Create(ctx context.Context, t model.OwnershipTransfer, now time.Time) (model.OwnershipTransfer, error) {
	row, err := r.tx.Queries(ctx).CreateOwnershipTransfer(ctx, sqlc.CreateOwnershipTransferParams{
		ID: t.ID, GroupID: t.GroupID, FromUserID: t.FromUserID, ToMemberID: t.ToMemberID, ExpiresAt: t.ExpiresAt, Now: now,
	})
	return toOwnershipTransfer(row), mapErr(err)
}

// GetForUpdate loads and row-locks a transfer of groupID. Call it inside
// WithTx.
func (r *OwnershipTransferRepository) GetForUpdate(ctx context.Context, groupID, id uuid.UUID) (model.OwnershipTransfer, error) {
	row, err := r.tx.Queries(ctx).GetOwnershipTransferForUpdate(ctx, sqlc.GetOwnershipTransferForUpdateParams{ID: id, GroupID: groupID})
	return toOwnershipTransfer(row), mapErr(err)
}

// Respond records the outcome of a pending transfer.
func (r *OwnershipTransferRepository) Respond(ctx context.Context, id uuid.UUID, status model.OwnershipTransferStatus, now time.Time) (model.OwnershipTransfer, error) {
	row, err := r.tx.Queries(ctx).RespondOwnershipTransfer(ctx, sqlc.RespondOwnershipTransferParams{
		ID: id, Status: string(status), RespondedAt: &now,
	})
	return toOwnershipTransfer(row), mapErr(err)
}

// ExpireOverdue marks the group's pending transfers past their deadline
// expired.
func (r *OwnershipTransferRepository) ExpireOverdue(ctx context.Context, groupID uuid.UUID, now time.Time) error {
	return mapErr(r.tx.Queries(ctx).ExpireOwnershipTransfers(ctx, sqlc.ExpireOwnershipTransfersParams{GroupID: groupID, Now: now}))
}

// CancelPending cancels the group's pending transfer; a non-nil toMemberID
// limits it to a transfer offered to that member.
func (r *OwnershipTransferRepository) CancelPending(ctx context.Context, groupID uuid.UUID, toMemberID *uuid.UUID) error {
	return mapErr(r.tx.Queries(ctx).CancelPendingOwnershipTransfers(ctx, sqlc.CancelPendingOwnershipTransfersParams{
		GroupID: groupID, ToMemberID: toMemberID,
	}))
}

func toOwnershipTransfer(row sqlc.OwnershipTransfer) model.OwnershipTransfer {
	return model.OwnershipTransfer{
		ID:          row.ID,
		GroupID:     row.GroupID,
		FromUserID:  row.FromUserID,
		ToMemberID:  row.ToMemberID,
		Status:      model.OwnershipTransferStatus(row.Status),
		ExpiresAt:   row.ExpiresAt,
		RespondedAt: row.RespondedAt,
		CreatedAt:   row.CreatedAt,
	}
}

// ExpireAllOverdue marks every pending transfer past its deadline at now as
// expired, in all groups.
func (r *OwnershipTransferRepository) ExpireAllOverdue(ctx context.Context, now time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).ExpireAllOwnershipTransfers(ctx, now)
	return n, mapErr(err)
}
