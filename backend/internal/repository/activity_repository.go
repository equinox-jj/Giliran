package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// errActivityOutsideTx guards BR-09: an activity entry must commit or roll
// back with the write it records.
var errActivityOutsideTx = errors.New("repository: activity log written outside a transaction")

// ActivityRepository appends to the activity log.
type ActivityRepository struct {
	tx *TxManager
}

func NewActivityRepository(tx *TxManager) *ActivityRepository {
	return &ActivityRepository{tx: tx}
}

// Insert appends l; now becomes its created_at. It refuses to run outside
// WithTx, so an entry never outlives a rolled-back write.
func (r *ActivityRepository) Insert(ctx context.Context, l model.ActivityLog, now time.Time) error {
	if !InTx(ctx) {
		return errActivityOutsideTx
	}
	return mapErr(r.tx.Queries(ctx).InsertActivityLog(ctx, sqlc.InsertActivityLogParams{
		GroupID:     l.GroupID,
		ActorType:   string(l.ActorType),
		ActorUserID: l.ActorUserID,
		Action:      string(l.Action),
		EntityType:  string(l.EntityType),
		EntityID:    l.EntityID,
		Before:      l.Before,
		After:       l.After,
		Now:         now,
	}))
}

// DrawCounts returns the paid and total payment counts recorded when the
// period was drawn, or ErrNotFound before the draw.
func (r *ActivityRepository) DrawCounts(ctx context.Context, periodID uuid.UUID) (paid, total int, err error) {
	row, err := r.tx.Queries(ctx).GetDrawCounts(ctx, periodID)
	return int(row.PaidCount), int(row.TotalCount), mapErr(err)
}

// List returns up to limit entries of the group older than beforeID, newest
// first; a nil beforeID starts at the newest entry.
func (r *ActivityRepository) List(ctx context.Context, groupID uuid.UUID, beforeID *int64, limit int32) ([]model.ActivityLog, error) {
	rows, err := r.tx.Queries(ctx).ListActivity(ctx, sqlc.ListActivityParams{GroupID: groupID, BeforeID: beforeID, RowLimit: limit})
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.ActivityLog, len(rows))
	for i, row := range rows {
		out[i] = toActivityLog(row)
	}
	return out, nil
}

// PaymentMembers maps each of the payment IDs to the member who owes it.
func (r *ActivityRepository) PaymentMembers(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]uuid.UUID, error) {
	out := map[uuid.UUID]uuid.UUID{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.tx.Queries(ctx).ListPaymentMembers(ctx, ids)
	if err != nil {
		return nil, mapErr(err)
	}
	for _, row := range rows {
		out[row.ID] = row.MemberID
	}
	return out, nil
}

// PayoutMembers maps each of the payout IDs to the winner it went to.
func (r *ActivityRepository) PayoutMembers(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]uuid.UUID, error) {
	out := map[uuid.UUID]uuid.UUID{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.tx.Queries(ctx).ListPayoutMembers(ctx, ids)
	if err != nil {
		return nil, mapErr(err)
	}
	for _, row := range rows {
		out[row.ID] = row.WinnerMemberID
	}
	return out, nil
}

func toActivityLog(row sqlc.ActivityLog) model.ActivityLog {
	return model.ActivityLog{
		ID:          row.ID,
		GroupID:     row.GroupID,
		ActorType:   model.ActorType(row.ActorType),
		ActorUserID: row.ActorUserID,
		Action:      model.Action(row.Action),
		EntityType:  model.EntityType(row.EntityType),
		EntityID:    row.EntityID,
		Before:      row.Before,
		After:       row.After,
		CreatedAt:   row.CreatedAt,
	}
}
