package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// PaymentRepository reads and writes payments and their proofs.
type PaymentRepository struct {
	tx *TxManager
}

func NewPaymentRepository(tx *TxManager) *PaymentRepository {
	return &PaymentRepository{tx: tx}
}

// ListSlotHolders returns the group's active slot holders with their share,
// by slot number.
func (r *PaymentRepository) ListSlotHolders(ctx context.Context, groupID uuid.UUID) ([]model.SlotMember, error) {
	rows, err := r.tx.Queries(ctx).ListSlotHolders(ctx, groupID)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.SlotMember, len(rows))
	for i, row := range rows {
		out[i] = model.SlotMember{SlotID: row.SlotID, MemberID: row.MemberID, SharePctBasisPoints: row.ShareBasisPoints}
	}
	return out, nil
}

// CreateAll inserts payments, all unpaid; their IDs are set here.
func (r *PaymentRepository) CreateAll(ctx context.Context, groupID, periodID uuid.UUID, payments []model.Payment, now time.Time) error {
	arg := sqlc.CreatePaymentsParams{GroupID: groupID, PeriodID: periodID, Now: now}
	for _, p := range payments {
		arg.Ids = append(arg.Ids, uuid.Must(uuid.NewV7()))
		arg.SlotIds = append(arg.SlotIds, p.SlotID)
		arg.MemberIds = append(arg.MemberIds, p.MemberID)
		arg.Amounts = append(arg.Amounts, p.Amount)
	}
	return mapErr(r.tx.Queries(ctx).CreatePayments(ctx, arg))
}

// PaymentView is a payment with its current proof, if any.
type PaymentView struct {
	Payment model.Payment
	Proof   *model.PaymentProof // only ID, ObjectKey, ContentType and CreatedAt are set
}

// ListByPeriod returns a period's payments by slot number.
func (r *PaymentRepository) ListByPeriod(ctx context.Context, periodID uuid.UUID) ([]PaymentView, error) {
	rows, err := r.tx.Queries(ctx).ListPeriodPayments(ctx, periodID)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]PaymentView, len(rows))
	for i, row := range rows {
		out[i] = toPaymentView(row.Payment, row.ProofObjectKey, row.ProofContentType, row.ProofCreatedAt)
	}
	return out, nil
}

// Get returns a payment of groupID.
func (r *PaymentRepository) Get(ctx context.Context, groupID, id uuid.UUID) (PaymentView, error) {
	row, err := r.tx.Queries(ctx).GetPayment(ctx, sqlc.GetPaymentParams{ID: id, GroupID: groupID})
	if err != nil {
		return PaymentView{}, mapErr(err)
	}
	return toPaymentView(row.Payment, row.ProofObjectKey, row.ProofContentType, row.ProofCreatedAt), nil
}

func toPaymentView(p sqlc.Payment, key, contentType *string, createdAt *time.Time) PaymentView {
	v := PaymentView{Payment: toPayment(p)}
	if p.CurrentProofID != nil && key != nil && contentType != nil && createdAt != nil {
		v.Proof = &model.PaymentProof{
			ID:          *p.CurrentProofID,
			PaymentID:   p.ID,
			ObjectKey:   *key,
			ContentType: model.ProofContentType(*contentType),
			CreatedAt:   *createdAt,
		}
	}
	return v
}

// GetForUpdate loads and row-locks a payment of groupID. Call it inside
// WithTx.
func (r *PaymentRepository) GetForUpdate(ctx context.Context, groupID, id uuid.UUID) (model.Payment, error) {
	row, err := r.tx.Queries(ctx).GetPaymentForUpdate(ctx, sqlc.GetPaymentForUpdateParams{ID: id, GroupID: groupID})
	return toPayment(row), mapErr(err)
}

// SetProof makes proofID the current proof and the payment pending review.
func (r *PaymentRepository) SetProof(ctx context.Context, id, proofID uuid.UUID) (model.Payment, error) {
	row, err := r.tx.Queries(ctx).SetPaymentProof(ctx, sqlc.SetPaymentProofParams{ID: id, ProofID: &proofID})
	return toPayment(row), mapErr(err)
}

// SetPaid marks the payment paid at now, reviewed by reviewer.
func (r *PaymentRepository) SetPaid(ctx context.Context, id uuid.UUID, method model.PaymentMethod, note *string, reviewer uuid.UUID, now time.Time) (model.Payment, error) {
	m := string(method)
	row, err := r.tx.Queries(ctx).SetPaymentPaid(ctx, sqlc.SetPaymentPaidParams{
		ID: id, Method: &m, Note: note, ReviewedBy: &reviewer, Now: now,
	})
	return toPayment(row), mapErr(err)
}

// Reject marks the payment rejected with reason.
func (r *PaymentRepository) Reject(ctx context.Context, id uuid.UUID, reason string, reviewer uuid.UUID, now time.Time) (model.Payment, error) {
	row, err := r.tx.Queries(ctx).RejectPayment(ctx, sqlc.RejectPaymentParams{
		ID: id, Reason: &reason, ReviewedBy: &reviewer, Now: now,
	})
	return toPayment(row), mapErr(err)
}

// PaymentSummary counts a period's payments by status, in rupiah for the
// amounts.
type PaymentSummary struct {
	TotalCount         int
	PaidCount          int
	PendingReviewCount int
	UnpaidCount        int
	RejectedCount      int
	CollectedAmount    int64
	ExpectedAmount     int64
}

// Summary returns the payment summary of a period.
func (r *PaymentRepository) Summary(ctx context.Context, periodID uuid.UUID) (PaymentSummary, error) {
	row, err := r.tx.Queries(ctx).GetPaymentSummary(ctx, periodID)
	if err != nil {
		return PaymentSummary{}, mapErr(err)
	}
	return PaymentSummary{
		TotalCount:         int(row.TotalCount),
		PaidCount:          int(row.PaidCount),
		PendingReviewCount: int(row.PendingReviewCount),
		UnpaidCount:        int(row.UnpaidCount),
		RejectedCount:      int(row.RejectedCount),
		CollectedAmount:    row.CollectedAmount,
		ExpectedAmount:     row.ExpectedAmount,
	}, nil
}

// CreateProof inserts p; now becomes its created_at.
func (r *PaymentRepository) CreateProof(ctx context.Context, p model.PaymentProof, now time.Time) (model.PaymentProof, error) {
	row, err := r.tx.Queries(ctx).CreatePaymentProof(ctx, sqlc.CreatePaymentProofParams{
		ID:          p.ID,
		PaymentID:   p.PaymentID,
		ObjectKey:   p.ObjectKey,
		ContentType: string(p.ContentType),
		SizeBytes:   p.SizeBytes,
		UploadedBy:  p.UploadedBy,
		Now:         now,
	})
	return toPaymentProof(row), mapErr(err)
}

// ListProofs returns every proof of a payment, newest first.
func (r *PaymentRepository) ListProofs(ctx context.Context, paymentID uuid.UUID) ([]model.PaymentProof, error) {
	rows, err := r.tx.Queries(ctx).ListPaymentProofs(ctx, paymentID)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.PaymentProof, len(rows))
	for i, row := range rows {
		out[i] = toPaymentProof(row)
	}
	return out, nil
}

func toPayment(row sqlc.Payment) model.Payment {
	p := model.Payment{
		ID:             row.ID,
		GroupID:        row.GroupID,
		PeriodID:       row.PeriodID,
		SlotID:         row.SlotID,
		MemberID:       row.MemberID,
		Amount:         row.Amount,
		Status:         model.PaymentStatus(row.Status),
		CurrentProofID: row.CurrentProofID,
		Note:           row.Note,
		RejectReason:   row.RejectReason,
		PaidAt:         row.PaidAt,
		ReviewedBy:     row.ReviewedBy,
		ReviewedAt:     row.ReviewedAt,
		CreatedAt:      row.CreatedAt,
		UpdatedAt:      row.UpdatedAt,
	}
	if row.Method != nil {
		m := model.PaymentMethod(*row.Method)
		p.Method = &m
	}
	return p
}

func toPaymentProof(row sqlc.PaymentProof) model.PaymentProof {
	return model.PaymentProof{
		ID:          row.ID,
		PaymentID:   row.PaymentID,
		ObjectKey:   row.ObjectKey,
		ContentType: model.ProofContentType(row.ContentType),
		SizeBytes:   row.SizeBytes,
		ImagePHash:  row.ImagePhash,
		UploadedBy:  row.UploadedBy,
		CreatedAt:   row.CreatedAt,
	}
}
