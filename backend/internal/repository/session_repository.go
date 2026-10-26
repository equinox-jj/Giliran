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

// RevokeOthers revokes every active session of userID except exceptID.
func (r *SessionRepository) RevokeOthers(ctx context.Context, userID, exceptID uuid.UUID, reason model.RevokedReason, now time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).RevokeOtherUserSessions(ctx, sqlc.RevokeOtherUserSessionsParams{
		UserID: userID, ExceptID: exceptID, Reason: string(reason), Now: now,
	})
	return n, mapErr(err)
}

// ListActive returns userID's sessions that are neither revoked nor expired at
// now, with currentID first and the rest most recently active first.
func (r *SessionRepository) ListActive(ctx context.Context, userID, currentID uuid.UUID, now time.Time) ([]model.Session, error) {
	rows, err := r.tx.Queries(ctx).ListActiveUserSessions(ctx, sqlc.ListActiveUserSessionsParams{UserID: userID, CurrentID: currentID, Now: now})
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.Session, len(rows))
	for i, row := range rows {
		out[i] = toSession(row)
	}
	return out, nil
}

// SetFCMToken stores the device's push token on session id if it belongs to
// userID and is still active, and reports whether it did.
func (r *SessionRepository) SetFCMToken(ctx context.Context, id, userID uuid.UUID, token string) (bool, error) {
	n, err := r.tx.Queries(ctx).SetSessionFCMToken(ctx, sqlc.SetSessionFCMTokenParams{ID: id, UserID: userID, FcmToken: token})
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

// RevokeAll revokes every active session of userID.
func (r *SessionRepository) RevokeAll(ctx context.Context, userID uuid.UUID, reason model.RevokedReason, now time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).RevokeAllUserSessions(ctx, sqlc.RevokeAllUserSessionsParams{UserID: userID, Reason: string(reason), Now: now})
	return n, mapErr(err)
}

// ListPushTokens returns the push tokens of the user's signed-in devices
// that have not expired at now.
func (r *SessionRepository) ListPushTokens(ctx context.Context, userID uuid.UUID, now time.Time) ([]string, error) {
	tokens, err := r.tx.Queries(ctx).ListUserPushTokens(ctx, sqlc.ListUserPushTokensParams{UserID: userID, Now: now})
	return tokens, mapErr(err)
}

// ClearPushTokens removes tokens that FCM no longer accepts from every
// session holding them.
func (r *SessionRepository) ClearPushTokens(ctx context.Context, tokens []string) (int64, error) {
	if len(tokens) == 0 {
		return 0, nil
	}
	n, err := r.tx.Queries(ctx).ClearPushTokens(ctx, tokens)
	return n, mapErr(err)
}

// DeleteStale deletes the sessions revoked or expired before cutoff.
func (r *SessionRepository) DeleteStale(ctx context.Context, cutoff time.Time) (int64, error) {
	n, err := r.tx.Queries(ctx).DeleteStaleSessions(ctx, cutoff)
	return n, mapErr(err)
}
