package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// SessionRepository reads and writes sessions (refresh tokens).
type SessionRepository struct {
	tx *TxManager
}

func NewSessionRepository(tx *TxManager) *SessionRepository {
	return &SessionRepository{tx: tx}
}

// Create inserts s; now becomes its created_at and last_active_at.
func (r *SessionRepository) Create(ctx context.Context, s model.Session, now time.Time) (model.Session, error) {
	row, err := r.tx.Queries(ctx).CreateSession(ctx, sqlc.CreateSessionParams{
		ID:               s.ID,
		UserID:           s.UserID,
		FamilyID:         s.FamilyID,
		RefreshTokenHash: s.RefreshTokenHash,
		DeviceName:       s.DeviceName,
		DevicePlatform:   string(s.DevicePlatform),
		FcmToken:         s.FCMToken,
		ExpiresAt:        s.ExpiresAt,
		Now:              now,
	})
	return toSession(row), mapErr(err)
}

// GetByRefreshTokenHashForUpdate loads and row-locks the session for a
// refresh token hash. Call it inside WithTx.
func (r *SessionRepository) GetByRefreshTokenHashForUpdate(ctx context.Context, hash string) (model.Session, error) {
	row, err := r.tx.Queries(ctx).GetSessionByRefreshTokenHashForUpdate(ctx, hash)
	return toSession(row), mapErr(err)
}

// Rotate revokes session id as rotated and points it at its successor.
func (r *SessionRepository) Rotate(ctx context.Context, id, replacedByID uuid.UUID, now time.Time) error {
	return mapErr(r.tx.Queries(ctx).RotateSession(ctx, sqlc.RotateSessionParams{ID: id, ReplacedByID: replacedByID, Now: now}))
}

// RevokeFamily revokes every still-active session of one sign-in.
func (r *SessionRepository) RevokeFamily(ctx context.Context, familyID uuid.UUID, reason model.RevokedReason, now time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).RevokeSessionFamily(ctx, sqlc.RevokeSessionFamilyParams{FamilyID: familyID, Reason: string(reason), Now: now})
	return n, mapErr(err)
}

// RevokeForUser revokes session id if it belongs to userID and is still
// active, and reports whether it did.
func (r *SessionRepository) RevokeForUser(ctx context.Context, id, userID uuid.UUID, reason model.RevokedReason, now time.Time) (bool, error) {
	n, err := r.tx.Queries(ctx).RevokeUserSession(ctx, sqlc.RevokeUserSessionParams{ID: id, UserID: userID, Reason: string(reason), Now: now})
	return n > 0, mapErr(err)
}

func toSession(row sqlc.Session) model.Session {
	s := model.Session{
		ID:               row.ID,
		UserID:           row.UserID,
		FamilyID:         row.FamilyID,
		RefreshTokenHash: row.RefreshTokenHash,
		ReplacedByID:     row.ReplacedByID,
		DeviceName:       row.DeviceName,
		DevicePlatform:   model.DevicePlatform(row.DevicePlatform),
		FCMToken:         row.FcmToken,
		LastActiveAt:     row.LastActiveAt,
		ExpiresAt:        row.ExpiresAt,
		RevokedAt:        row.RevokedAt,
		CreatedAt:        row.CreatedAt,
	}
	if row.RevokedReason != nil {
		reason := model.RevokedReason(*row.RevokedReason)
		s.RevokedReason = &reason
	}
	return s
}
