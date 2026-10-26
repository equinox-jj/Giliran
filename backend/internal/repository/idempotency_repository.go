package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// IdempotencyRepository stores the responses of idempotent writes.
type IdempotencyRepository struct {
	tx *TxManager
}

func NewIdempotencyRepository(tx *TxManager) *IdempotencyRepository {
	return &IdempotencyRepository{tx: tx}
}

// Claim inserts k without a response and reports whether it did. When
// another transaction holds an uncommitted claim of the same key, Claim
// waits for it; once that commits, Claim returns false. Call it inside
// WithTx, so the claim commits with the write it guards.
func (r *IdempotencyRepository) Claim(ctx context.Context, k model.IdempotencyKey, now time.Time) (bool, error) {
	n, err := r.tx.Queries(ctx).ClaimIdempotencyKey(ctx, sqlc.ClaimIdempotencyKeyParams{
		UserID:      k.UserID,
		Key:         k.Key,
		Method:      k.Method,
		Path:        k.Path,
		RequestHash: k.RequestHash,
		Now:         now,
		ExpiresAt:   now.Add(model.IdempotencyKeyTTL),
	})
	return n == 1, mapErr(err)
}

func (r *IdempotencyRepository) Get(ctx context.Context, userID uuid.UUID, key string) (model.IdempotencyKey, error) {
	row, err := r.tx.Queries(ctx).GetIdempotencyKey(ctx, sqlc.GetIdempotencyKeyParams{UserID: userID, Key: key})
	return model.IdempotencyKey{
		UserID:         row.UserID,
		Key:            row.Key,
		Method:         row.Method,
		Path:           row.Path,
		RequestHash:    row.RequestHash,
		ResponseStatus: row.ResponseStatus,
		ResponseBody:   row.ResponseBody,
		CreatedAt:      row.CreatedAt,
		ExpiresAt:      row.ExpiresAt,
	}, mapErr(err)
}

// SaveResponse stores the response of a claimed key.
func (r *IdempotencyRepository) SaveResponse(ctx context.Context, userID uuid.UUID, key string, status int16, body []byte) error {
	return mapErr(r.tx.Queries(ctx).SaveIdempotencyResponse(ctx, sqlc.SaveIdempotencyResponseParams{
		UserID: userID, Key: key, ResponseStatus: status, ResponseBody: body,
	}))
}

// Delete removes a key, so an expired one can be claimed again.
func (r *IdempotencyRepository) Delete(ctx context.Context, userID uuid.UUID, key string) error {
	return mapErr(r.tx.Queries(ctx).DeleteIdempotencyKey(ctx, sqlc.DeleteIdempotencyKeyParams{UserID: userID, Key: key}))
}
