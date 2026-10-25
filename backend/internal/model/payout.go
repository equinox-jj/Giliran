package model

import (
	"time"

	"github.com/google/uuid"
)

// Payout records the pot handed to a period's winner, mirroring the payouts
// table (DB_SCHEME §3.11). Each period has at most one.
type Payout struct {
	ID             uuid.UUID  `db:"id"`
	PeriodID       uuid.UUID  `db:"period_id"`
	WinnerMemberID uuid.UUID  `db:"winner_member_id"`
	Amount         int64      `db:"amount"`    // rupiah handed over
	ProofKey       *string    `db:"proof_key"` // MinIO object key of an optional transfer proof
	Note           *string    `db:"note"`
	RecordedBy     uuid.UUID  `db:"recorded_by"`
	RecordedAt     time.Time  `db:"recorded_at"`
	ConfirmedBy    *uuid.UUID `db:"confirmed_by"` // the winner; set together with ConfirmedAt
	ConfirmedAt    *time.Time `db:"confirmed_at"`
}

// IsConfirmed reports whether the winner has confirmed receiving the pot.
func (p *Payout) IsConfirmed() bool {
	return p.ConfirmedAt != nil
}
