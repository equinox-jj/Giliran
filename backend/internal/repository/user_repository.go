package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// UserRepository reads and writes users and their settings. Lookups skip
// soft-deleted users.
type UserRepository struct {
	tx *TxManager
}

func NewUserRepository(tx *TxManager) *UserRepository {
	return &UserRepository{tx: tx}
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (model.User, error) {
	row, err := r.tx.Queries(ctx).GetUserByID(ctx, id)
	return toUser(row), mapErr(err)
}

func (r *UserRepository) GetByFirebaseUID(ctx context.Context, uid string) (model.User, error) {
	row, err := r.tx.Queries(ctx).GetUserByFirebaseUID(ctx, &uid)
	return toUser(row), mapErr(err)
}

func (r *UserRepository) GetByPhone(ctx context.Context, phone string) (model.User, error) {
	row, err := r.tx.Queries(ctx).GetUserByPhone(ctx, &phone)
	return toUser(row), mapErr(err)
}

// Create inserts a user with only an identity; everything else is set later.
// A phone or Firebase UID already used by an active user is ErrDuplicate.
func (r *UserRepository) Create(ctx context.Context, id uuid.UUID, phone, firebaseUID string) (model.User, error) {
	row, err := r.tx.Queries(ctx).CreateUser(ctx, sqlc.CreateUserParams{ID: id, Phone: &phone, FirebaseUID: &firebaseUID})
	return toUser(row), mapErr(err)
}

// SetFirebaseUID links an existing user to a Firebase account.
func (r *UserRepository) SetFirebaseUID(ctx context.Context, id uuid.UUID, uid string) (model.User, error) {
	row, err := r.tx.Queries(ctx).SetUserFirebaseUID(ctx, sqlc.SetUserFirebaseUIDParams{ID: id, FirebaseUID: &uid})
	return toUser(row), mapErr(err)
}

// GetByIDForUpdate loads and row-locks a user. Call it inside WithTx.
func (r *UserRepository) GetByIDForUpdate(ctx context.Context, id uuid.UUID) (model.User, error) {
	row, err := r.tx.Queries(ctx).GetUserByIDForUpdate(ctx, id)
	return toUser(row), mapErr(err)
}

// SetPIN stores a new PIN hash and clears failed attempts and any lock.
func (r *UserRepository) SetPIN(ctx context.Context, id uuid.UUID, pinHash string) error {
	return mapErr(r.tx.Queries(ctx).SetUserPIN(ctx, sqlc.SetUserPINParams{ID: id, PINHash: &pinHash}))
}

// SetPINAttempts records the failed-attempt count and lock expiry.
func (r *UserRepository) SetPINAttempts(ctx context.Context, id uuid.UUID, failed int16, lockedUntil *time.Time) error {
	return mapErr(r.tx.Queries(ctx).SetUserPINAttempts(ctx, sqlc.SetUserPINAttemptsParams{
		ID: id, PINFailedCount: failed, PINLockedUntil: lockedUntil,
	}))
}

// CreateSettings inserts the user's settings row with the defaults.
func (r *UserRepository) CreateSettings(ctx context.Context, userID uuid.UUID) error {
	return mapErr(r.tx.Queries(ctx).CreateUserSettings(ctx, userID))
}

func toUser(row sqlc.User) model.User {
	u := model.User{
		ID:             row.ID,
		FirebaseUID:    row.FirebaseUID,
		Name:           row.Name,
		AvatarKey:      row.AvatarKey,
		PINHash:        row.PINHash,
		PINFailedCount: row.PINFailedCount,
		PINLockedUntil: row.PINLockedUntil,
		CreatedAt:      row.CreatedAt,
		UpdatedAt:      row.UpdatedAt,
		DeletedAt:      row.DeletedAt,
	}
	if row.Phone != nil { // nil only on deleted users
		u.Phone = *row.Phone
	}
	return u
}
