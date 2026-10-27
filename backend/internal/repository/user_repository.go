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

// GetByEmail looks up the active user with this (lowercase) email.
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (model.User, error) {
	row, err := r.tx.Queries(ctx).GetUserByEmail(ctx, email)
	return toUser(row), mapErr(err)
}

// GetByEmailForUpdate loads and row-locks the active user with this email.
// Call it inside WithTx.
func (r *UserRepository) GetByEmailForUpdate(ctx context.Context, email string) (model.User, error) {
	row, err := r.tx.Queries(ctx).GetUserByEmailForUpdate(ctx, email)
	return toUser(row), mapErr(err)
}

// Create inserts a user with only a verified email; everything else is set
// later. An email already used by an active user is ErrDuplicate.
func (r *UserRepository) Create(ctx context.Context, id uuid.UUID, email string, verifiedAt time.Time) (model.User, error) {
	row, err := r.tx.Queries(ctx).CreateUser(ctx, sqlc.CreateUserParams{ID: id, Email: email, VerifiedAt: verifiedAt})
	return toUser(row), mapErr(err)
}

// UpdateEmail moves the user to a newly verified email. An email already used
// by another active user is ErrDuplicate.
func (r *UserRepository) UpdateEmail(ctx context.Context, id uuid.UUID, email string, verifiedAt time.Time) (model.User, error) {
	row, err := r.tx.Queries(ctx).UpdateUserEmail(ctx, sqlc.UpdateUserEmailParams{ID: id, Email: email, VerifiedAt: verifiedAt})
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

// UpdateName sets the display name.
func (r *UserRepository) UpdateName(ctx context.Context, id uuid.UUID, name string) (model.User, error) {
	row, err := r.tx.Queries(ctx).UpdateUserName(ctx, sqlc.UpdateUserNameParams{ID: id, Name: &name})
	return toUser(row), mapErr(err)
}

// ProfileChange lists the profile fields to change. A nil Name keeps the
// name; Phone is applied only when SetPhone is true, and nil then clears it.
type ProfileChange struct {
	Name     *string
	SetPhone bool
	Phone    *string
}

// UpdateProfile applies c and returns the result.
func (r *UserRepository) UpdateProfile(ctx context.Context, id uuid.UUID, c ProfileChange) (model.User, error) {
	row, err := r.tx.Queries(ctx).UpdateUserProfile(ctx, sqlc.UpdateUserProfileParams{
		ID: id, Name: c.Name, SetPhone: c.SetPhone, Phone: c.Phone,
	})
	return toUser(row), mapErr(err)
}

// SetAvatarKey points the user at a new avatar object; nil removes it.
func (r *UserRepository) SetAvatarKey(ctx context.Context, id uuid.UUID, key *string) (model.User, error) {
	row, err := r.tx.Queries(ctx).SetUserAvatarKey(ctx, sqlc.SetUserAvatarKeyParams{ID: id, AvatarKey: key})
	return toUser(row), mapErr(err)
}

func (r *UserRepository) GetSettings(ctx context.Context, userID uuid.UUID) (model.UserSettings, error) {
	row, err := r.tx.Queries(ctx).GetUserSettings(ctx, userID)
	return toUserSettings(row), mapErr(err)
}

// SettingsChange lists the settings to change; nil fields keep their value.
type SettingsChange struct {
	Language               *model.Language
	NotifyPaymentReminders *bool
	NotifyDrawResults      *bool
	NotifyGroupActivity    *bool
}

// UpdateSettings applies the non-nil fields of c and returns the result.
func (r *UserRepository) UpdateSettings(ctx context.Context, userID uuid.UUID, c SettingsChange) (model.UserSettings, error) {
	arg := sqlc.UpdateUserSettingsParams{
		UserID:                 userID,
		NotifyPaymentReminders: c.NotifyPaymentReminders,
		NotifyDrawResults:      c.NotifyDrawResults,
		NotifyGroupActivity:    c.NotifyGroupActivity,
	}
	if c.Language != nil {
		lang := string(*c.Language)
		arg.Language = &lang
	}
	row, err := r.tx.Queries(ctx).UpdateUserSettings(ctx, arg)
	return toUserSettings(row), mapErr(err)
}

func toUser(row sqlc.User) model.User {
	return model.User{
		ID:              row.ID,
		Email:           row.Email,
		EmailVerifiedAt: row.EmailVerifiedAt,
		Phone:           row.Phone,
		Name:            row.Name,
		AvatarKey:       row.AvatarKey,
		PINHash:         row.PINHash,
		PINFailedCount:  row.PINFailedCount,
		PINLockedUntil:  row.PINLockedUntil,
		CreatedAt:       row.CreatedAt,
		UpdatedAt:       row.UpdatedAt,
		DeletedAt:       row.DeletedAt,
	}
}

func toUserSettings(row sqlc.UserSetting) model.UserSettings {
	return model.UserSettings{
		UserID:                 row.UserID,
		Language:               model.Language(row.Language),
		NotifyPaymentReminders: row.NotifyPaymentReminders,
		NotifyDrawResults:      row.NotifyDrawResults,
		NotifyGroupActivity:    row.NotifyGroupActivity,
		UpdatedAt:              row.UpdatedAt,
	}
}

// Anonymize soft-deletes the user and clears their personal data. An
// already deleted user is ErrNotFound.
func (r *UserRepository) Anonymize(ctx context.Context, id uuid.UUID, now time.Time) error {
	n, err := r.tx.Queries(ctx).AnonymizeUser(ctx, sqlc.AnonymizeUserParams{ID: id, Now: now})
	if err != nil {
		return mapErr(err)
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}
