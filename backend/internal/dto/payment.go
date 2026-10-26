package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// RejectPaymentRequest is the body of POST .../payments/{payment_id}/reject.
// The service trims the reason and checks its length again.
type RejectPaymentRequest struct {
	Reason string `json:"reason" validate:"required,min=3,max=500"`
}

// MarkPaidRequest is the body of POST .../payments/{payment_id}/mark-paid.
type MarkPaidRequest struct {
	Method string  `json:"method" validate:"required,oneof=cash transfer other"`
	Note   *string `json:"note" validate:"omitnil,max=500"`
}

// PaymentProof is the PaymentProof schema.
type PaymentProof struct {
	ID          uuid.UUID              `json:"id"`
	URL         string                 `json:"url"`
	ContentType model.ProofContentType `json:"content_type"`
	UploadedAt  time.Time              `json:"uploaded_at"`
}

func NewPaymentProof(p service.Proof) PaymentProof {
	return PaymentProof{ID: p.ID, URL: p.URL, ContentType: p.ContentType, UploadedAt: p.CreatedAt}
}

// Payment is the Payment schema.
type Payment struct {
	ID           uuid.UUID            `json:"id"`
	PeriodID     uuid.UUID            `json:"period_id"`
	Member       MemberRef            `json:"member"`
	Amount       int64                `json:"amount"`
	Status       model.PaymentStatus  `json:"status"`
	Method       *model.PaymentMethod `json:"method"`
	CurrentProof *PaymentProof        `json:"current_proof"`
	Note         *string              `json:"note"`
	RejectReason *string              `json:"reject_reason"`
	PaidAt       *time.Time           `json:"paid_at"`
	ReviewedBy   *UserSummary         `json:"reviewed_by"`
	ReviewedAt   *time.Time           `json:"reviewed_at"`
	IsMine       bool                 `json:"is_mine"`
	UpdatedAt    time.Time            `json:"updated_at"`
}

func NewPayment(v service.PaymentView) Payment {
	p := v.Payment
	out := Payment{
		ID:           p.ID,
		PeriodID:     p.PeriodID,
		Member:       NewMemberRef(v.Member),
		Amount:       p.Amount,
		Status:       p.Status,
		Method:       p.Method,
		Note:         p.Note,
		RejectReason: p.RejectReason,
		PaidAt:       p.PaidAt,
		ReviewedAt:   p.ReviewedAt,
		IsMine:       v.IsMine,
		UpdatedAt:    p.UpdatedAt,
	}
	if v.CurrentProof != nil {
		pr := NewPaymentProof(*v.CurrentProof)
		out.CurrentProof = &pr
	}
	if v.ReviewedBy != nil {
		u := NewUserSummary(*v.ReviewedBy)
		out.ReviewedBy = &u
	}
	return out
}

func NewPayments(vs []service.PaymentView) []Payment {
	out := make([]Payment, len(vs))
	for i, v := range vs {
		out[i] = NewPayment(v)
	}
	return out
}

// PaymentDetail is the PaymentDetail schema: a payment with every proof,
// newest first.
type PaymentDetail struct {
	Payment
	Proofs []PaymentProof `json:"proofs"`
}

func NewPaymentDetail(d service.PaymentDetail) PaymentDetail {
	out := PaymentDetail{Payment: NewPayment(d.PaymentView), Proofs: make([]PaymentProof, len(d.Proofs))}
	for i, p := range d.Proofs {
		out.Proofs[i] = NewPaymentProof(p)
	}
	return out
}

// PaymentBoardMeta is the meta of the payment board.
type PaymentBoardMeta struct {
	Summary PaymentSummary `json:"summary"`
}
