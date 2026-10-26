package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// Payout is the Payout schema.
type Payout struct {
	ID          uuid.UUID   `json:"id"`
	PeriodID    uuid.UUID   `json:"period_id"`
	Winner      MemberRef   `json:"winner"`
	Amount      int64       `json:"amount"`
	ProofURL    *string     `json:"proof_url"`
	Note        *string     `json:"note"`
	RecordedBy  UserSummary `json:"recorded_by"`
	RecordedAt  time.Time   `json:"recorded_at"`
	ConfirmedAt *time.Time  `json:"confirmed_at"`
}

func NewPayout(v service.PayoutView) Payout {
	p := v.Payout
	return Payout{
		ID:          p.ID,
		PeriodID:    p.PeriodID,
		Winner:      NewMemberRef(v.Winner),
		Amount:      p.Amount,
		ProofURL:    v.ProofURL,
		Note:        p.Note,
		RecordedBy:  NewUserSummary(v.RecordedBy),
		RecordedAt:  p.RecordedAt,
		ConfirmedAt: p.ConfirmedAt,
	}
}
