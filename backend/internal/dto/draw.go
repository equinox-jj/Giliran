package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// Draw statuses: before the draw only the commitment exists.
const (
	DrawStatusCommitted = "committed"
	DrawStatusDrawn     = "drawn"
)

// RunDrawRequest is the RunDrawRequest schema. The body is optional.
type RunDrawRequest struct {
	ConfirmIncomplete bool `json:"confirm_incomplete"`
}

// DrawSlot is the DrawSlot schema.
type DrawSlot struct {
	SlotID      uuid.UUID `json:"slot_id"`
	SlotNo      int16     `json:"slot_no"`
	DisplayName string    `json:"display_name"`
}

func NewDrawSlot(s service.DrawSlot) DrawSlot {
	return DrawSlot(s)
}

func newDrawSlots(ss []service.DrawSlot) []DrawSlot {
	out := make([]DrawSlot, len(ss))
	for i, s := range ss {
		out[i] = NewDrawSlot(s)
	}
	return out
}

// Draw is the Draw schema. The seed is set only once the period is drawn.
type Draw struct {
	PeriodID         uuid.UUID        `json:"period_id"`
	PeriodNo         int16            `json:"period_no"`
	Method           model.DrawMethod `json:"method"`
	Algorithm        string           `json:"algorithm"`
	Status           string           `json:"status"`
	SeedHash         *string          `json:"seed_hash"`
	Seed             *string          `json:"seed"`
	EligibleSlots    []DrawSlot       `json:"eligible_slots"`
	Winner           *DrawSlot        `json:"winner"`
	PaidCountAtDraw  *int             `json:"paid_count_at_draw"`
	TotalCountAtDraw *int             `json:"total_count_at_draw"`
	DrawnAt          *time.Time       `json:"drawn_at"`
	DrawnBy          *UserSummary     `json:"drawn_by"`
	VerificationCode *string          `json:"verification_code"`
	VerifyURL        *string          `json:"verify_url"`
}

func NewDraw(v service.DrawView) Draw {
	p := v.Period
	out := Draw{
		PeriodID:         p.ID,
		PeriodNo:         p.PeriodNo,
		Method:           v.Method,
		Algorithm:        p.DrawAlgorithm,
		Status:           DrawStatusCommitted,
		SeedHash:         p.SeedHash,
		EligibleSlots:    newDrawSlots(v.EligibleSlots),
		PaidCountAtDraw:  v.PaidCount,
		TotalCountAtDraw: v.TotalCount,
		DrawnAt:          p.DrawnAt,
		VerificationCode: p.VerificationCode,
		VerifyURL:        v.VerifyURL,
	}
	if p.IsDrawn() {
		out.Status = DrawStatusDrawn
		out.Seed = p.Seed
	}
	if v.Winner != nil {
		w := NewDrawSlot(*v.Winner)
		out.Winner = &w
	}
	if v.DrawnBy != nil {
		by := NewUserSummary(*v.DrawnBy)
		out.DrawnBy = &by
	}
	return out
}

// PublicDraw is the PublicDraw schema.
type PublicDraw struct {
	GroupName               string     `json:"group_name"`
	PeriodNo                int16      `json:"period_no"`
	TotalPeriods            int16      `json:"total_periods"`
	PeriodID                uuid.UUID  `json:"period_id"`
	Algorithm               string     `json:"algorithm"`
	SeedHash                *string    `json:"seed_hash"`
	Seed                    *string    `json:"seed"`
	SeedHashPublishedAt     *time.Time `json:"seed_hash_published_at"`
	EligibleSlots           []DrawSlot `json:"eligible_slots"`
	Winner                  DrawSlot   `json:"winner"`
	DrawnAt                 time.Time  `json:"drawn_at"`
	HashMatches             bool       `json:"hash_matches"`
	RecomputedWinnerMatches bool       `json:"recomputed_winner_matches"`
}

func NewPublicDraw(d service.PublicDraw) PublicDraw {
	return PublicDraw{
		GroupName:               d.GroupName,
		PeriodNo:                d.PeriodNo,
		TotalPeriods:            d.TotalPeriods,
		PeriodID:                d.PeriodID,
		Algorithm:               d.Algorithm,
		SeedHash:                d.SeedHash,
		Seed:                    d.Seed,
		SeedHashPublishedAt:     d.SeedHashPublishedAt,
		EligibleSlots:           newDrawSlots(d.EligibleSlots),
		Winner:                  NewDrawSlot(d.Winner),
		DrawnAt:                 d.DrawnAt,
		HashMatches:             d.HashMatches,
		RecomputedWinnerMatches: d.WinnerMatches,
	}
}
