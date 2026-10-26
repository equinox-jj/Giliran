package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// PaymentSummary is the PaymentSummary schema.
type PaymentSummary struct {
	TotalCount         int   `json:"total_count"`
	PaidCount          int   `json:"paid_count"`
	PendingReviewCount int   `json:"pending_review_count"`
	UnpaidCount        int   `json:"unpaid_count"`
	RejectedCount      int   `json:"rejected_count"`
	CollectedAmount    int64 `json:"collected_amount"`
	ExpectedAmount     int64 `json:"expected_amount"`
}

func NewPaymentSummary(s repository.PaymentSummary) PaymentSummary {
	return PaymentSummary(s)
}

// Period is the Period schema. It has no seed: the draw reveals that.
type Period struct {
	ID               uuid.UUID          `json:"id"`
	PeriodNo         int16              `json:"period_no"`
	DueDate          string             `json:"due_date"`
	DrawDate         string             `json:"draw_date"`
	Status           model.PeriodStatus `json:"status"`
	SeedHash         *string            `json:"seed_hash"`
	Winner           *MemberRef         `json:"winner"`
	DrawnAt          *time.Time         `json:"drawn_at"`
	VerificationCode *string            `json:"verification_code"`
	PaymentSummary   *PaymentSummary    `json:"payment_summary"`
	PayoutRecorded   bool               `json:"payout_recorded"`
	PayoutConfirmed  bool               `json:"payout_confirmed"`
}

func NewPeriod(d service.PeriodDetail) Period {
	p := d.Period
	out := Period{
		ID:               p.ID,
		PeriodNo:         p.PeriodNo,
		DueDate:          p.DueDate.Format(DateLayout),
		DrawDate:         p.DrawDate.Format(DateLayout),
		Status:           p.Status,
		SeedHash:         p.SeedHash,
		DrawnAt:          p.DrawnAt,
		VerificationCode: p.VerificationCode,
		PayoutRecorded:   d.PayoutRecorded,
		PayoutConfirmed:  d.PayoutConfirmed,
	}
	if d.Winner != nil {
		w := NewMemberRef(*d.Winner)
		out.Winner = &w
	}
	if d.Summary != nil {
		s := NewPaymentSummary(*d.Summary)
		out.PaymentSummary = &s
	}
	return out
}

func NewPeriods(ds []service.PeriodDetail) []Period {
	out := make([]Period, len(ds))
	for i, d := range ds {
		out[i] = NewPeriod(d)
	}
	return out
}
