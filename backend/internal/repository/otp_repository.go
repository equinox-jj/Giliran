package repository

import (
	"context"
	"errors"
	"net/netip"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// OTPRepository reads and writes email OTP requests (DB_SCHEME §3.16).
type OTPRepository struct {
	tx *TxManager
}

func NewOTPRepository(tx *TxManager) *OTPRepository {
	return &OTPRepository{tx: tx}
}

// Create inserts a pending request; now becomes its created_at and
// last_sent_at. A second pending request for the same email and purpose is
// ErrDuplicate, so cancel the previous one first (CancelPending).
func (r *OTPRepository) Create(ctx context.Context, o model.OTPRequest, now time.Time) (model.OTPRequest, error) {
	row, err := r.tx.Queries(ctx).CreateOtpRequest(ctx, sqlc.CreateOtpRequestParams{
		ID:             o.ID,
		Purpose:        string(o.Purpose),
		Email:          o.Email,
		UserID:         o.UserID,
		CodeHash:       o.CodeHash,
		SendStatus:     string(o.SendStatus),
		DeviceName:     o.DeviceName,
		DevicePlatform: string(o.DevicePlatform),
		FcmToken:       o.FCMToken,
		RequesterIP:    o.RequesterIP,
		Now:            now,
		ExpiresAt:      o.ExpiresAt,
	})
	return toOTPRequest(row), mapErr(err)
}

// LockEmail holds a transaction-scoped lock on email and purpose. It fails
// outside a transaction, where the lock would end with the statement.
func (r *OTPRepository) LockEmail(ctx context.Context, email string, purpose model.OTPPurpose) error {
	if !InTx(ctx) {
		return errors.New("repository: LockEmail needs a transaction")
	}
	return mapErr(r.tx.Queries(ctx).LockOtpEmail(ctx, sqlc.LockOtpEmailParams{Email: email, Purpose: string(purpose)}))
}

// CancelPending cancels the pending request for email and purpose, if any.
func (r *OTPRepository) CancelPending(ctx context.Context, email string, purpose model.OTPPurpose) (int64, error) {
	n, err := r.tx.Queries(ctx).CancelPendingOtp(ctx, sqlc.CancelPendingOtpParams{Email: email, Purpose: string(purpose)})
	return n, mapErr(err)
}

// CancelPendingForUser cancels every pending request tied to userID.
func (r *OTPRepository) CancelPendingForUser(ctx context.Context, userID uuid.UUID) (int64, error) {
	n, err := r.tx.Queries(ctx).CancelPendingOtpForUser(ctx, userID)
	return n, mapErr(err)
}

func (r *OTPRepository) Get(ctx context.Context, id uuid.UUID) (model.OTPRequest, error) {
	row, err := r.tx.Queries(ctx).GetOtpRequest(ctx, id)
	return toOTPRequest(row), mapErr(err)
}

// GetForUpdate loads and row-locks a request. Call it inside WithTx.
func (r *OTPRepository) GetForUpdate(ctx context.Context, id uuid.UUID) (model.OTPRequest, error) {
	row, err := r.tx.Queries(ctx).GetOtpRequestForUpdate(ctx, id)
	return toOTPRequest(row), mapErr(err)
}

// RecordFailure counts a wrong code and locks the request at
// model.OTPMaxAttempts. A request that is no longer pending is ErrNotFound.
func (r *OTPRepository) RecordFailure(ctx context.Context, id uuid.UUID) (model.OTPRequest, error) {
	row, err := r.tx.Queries(ctx).RecordOtpFailure(ctx, id)
	return toOTPRequest(row), mapErr(err)
}

// Consume marks a pending request used by userID at now. A request that is no
// longer pending is ErrNotFound.
func (r *OTPRepository) Consume(ctx context.Context, id, userID uuid.UUID, now time.Time) (model.OTPRequest, error) {
	row, err := r.tx.Queries(ctx).ConsumeOtpRequest(ctx, sqlc.ConsumeOtpRequestParams{ID: id, UserID: userID, Now: now})
	return toOTPRequest(row), mapErr(err)
}

// Resend replaces the code with codeHash, resets attempts and moves the
// expiry. It is ErrNotFound unless the request is pending, was last sent at
// or before sentBefore, and has resends left.
func (r *OTPRepository) Resend(ctx context.Context, id uuid.UUID, codeHash string, now, expiresAt, sentBefore time.Time) (model.OTPRequest, error) {
	row, err := r.tx.Queries(ctx).ResendOtpRequest(ctx, sqlc.ResendOtpRequestParams{
		ID: id, CodeHash: codeHash, Now: now, ExpiresAt: expiresAt, SentBefore: sentBefore,
	})
	return toOTPRequest(row), mapErr(err)
}

// MarkSent records the email job's outcome for the code sent at resendCount,
// and reports whether it did: a newer resend or a skipped request is left
// alone.
func (r *OTPRepository) MarkSent(ctx context.Context, id uuid.UUID, resendCount int16, status model.OTPSendStatus, providerMessageID *string) (bool, error) {
	n, err := r.tx.Queries(ctx).MarkOtpSent(ctx, sqlc.MarkOtpSentParams{
		ID: id, ResendCount: resendCount, SendStatus: string(status), ProviderMessageID: providerMessageID,
	})
	return n > 0, mapErr(err)
}

// ExpireDue marks pending requests past their expiry at now as expired.
func (r *OTPRepository) ExpireDue(ctx context.Context, now time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).ExpireOtpRequests(ctx, now)
	return n, mapErr(err)
}

// CountRecentByEmail counts the requests for email created at or after since.
func (r *OTPRepository) CountRecentByEmail(ctx context.Context, email string, since time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).CountRecentOtpByEmail(ctx, sqlc.CountRecentOtpByEmailParams{Email: email, Since: since})
	return n, mapErr(err)
}

// CountRecentByIP counts the requests from ip created at or after since.
func (r *OTPRepository) CountRecentByIP(ctx context.Context, ip netip.Addr, since time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).CountRecentOtpByIP(ctx, sqlc.CountRecentOtpByIPParams{RequesterIP: ip, Since: since})
	return n, mapErr(err)
}

// DeleteBefore deletes requests created before before, in any status.
func (r *OTPRepository) DeleteBefore(ctx context.Context, before time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).DeleteOtpRequestsBefore(ctx, before)
	return n, mapErr(err)
}

func toOTPRequest(row sqlc.EmailOtpRequest) model.OTPRequest {
	return model.OTPRequest{
		ID:                row.ID,
		Purpose:           model.OTPPurpose(row.Purpose),
		Email:             row.Email,
		UserID:            row.UserID,
		CodeHash:          row.CodeHash,
		Attempts:          row.Attempts,
		ResendCount:       row.ResendCount,
		LastSentAt:        row.LastSentAt,
		SendStatus:        model.OTPSendStatus(row.SendStatus),
		ProviderMessageID: row.ProviderMessageID,
		DeviceName:        row.DeviceName,
		DevicePlatform:    model.DevicePlatform(row.DevicePlatform),
		FCMToken:          row.FcmToken,
		RequesterIP:       row.RequesterIP,
		Status:            model.OTPStatus(row.Status),
		ExpiresAt:         row.ExpiresAt,
		ConsumedAt:        row.ConsumedAt,
		CreatedAt:         row.CreatedAt,
	}
}
