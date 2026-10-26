package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// PayoutRepository reads and writes the pot handed to each period's winner.
type PayoutRepository struct {
	tx *TxManager
}

func NewPayoutRepository(tx *TxManager) *PayoutRepository {
	return &PayoutRepository{tx: tx}
}

// Create inserts p, recorded at now. A period has one payout; a second is
// ErrDuplicate.
func (r *PayoutRepository) Create(ctx context.Context, p model.Payout, now time.Time) (model.Payout, error) {
	row, err := r.tx.Queries(ctx).CreatePayout(ctx, sqlc.CreatePayoutParams{
		ID:             p.ID,
		PeriodID:       p.PeriodID,
		WinnerMemberID: p.WinnerMemberID,
		Amount:         p.Amount,
		ProofKey:       p.ProofKey,
		Note:           p.Note,
		RecordedBy:     p.RecordedBy,
		Now:            now,
	})
	return toPayout(row), mapErr(err)
}

// GetByPeriod returns the payout of periodID.
func (r *PayoutRepository) GetByPeriod(ctx context.Context, periodID uuid.UUID) (model.Payout, error) {
	row, err := r.tx.Queries(ctx).GetPayoutByPeriod(ctx, periodID)
	return toPayout(row), mapErr(err)
}

// Confirm records that userID received the payout. An already confirmed
// payout is ErrNotFound.
func (r *PayoutRepository) Confirm(ctx context.Context, id, userID uuid.UUID, now time.Time) (model.Payout, error) {
	row, err := r.tx.Queries(ctx).ConfirmPayout(ctx, sqlc.ConfirmPayoutParams{ID: id, ConfirmedBy: &userID, Now: &now})
	return toPayout(row), mapErr(err)
}

func toPayout(row sqlc.Payout) model.Payout {
	return model.Payout{
		ID:             row.ID,
		PeriodID:       row.PeriodID,
		WinnerMemberID: row.WinnerMemberID,
		Amount:         row.Amount,
		ProofKey:       row.ProofKey,
		Note:           row.Note,
		RecordedBy:     row.RecordedBy,
		RecordedAt:     row.RecordedAt,
		ConfirmedBy:    row.ConfirmedBy,
		ConfirmedAt:    row.ConfirmedAt,
	}
}
