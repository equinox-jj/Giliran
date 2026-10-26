package repository

import (
	"context"
	"errors"
	"time"

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
