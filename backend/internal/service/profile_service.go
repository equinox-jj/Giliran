package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/images"
)

// Display name length limits (users.name CHECK).
const (
	nameMinLen = 2
	nameMaxLen = 50
)

// Profile is a user as they see themselves: the row plus a presigned URL for
// their avatar, or nil when they have none.
type Profile struct {
	User      model.User
	AvatarURL *string
}

// profileOf presigns user's avatar.
func profileOf(ctx context.Context, store storage.Storage, user model.User) (Profile, error) {
	p := Profile{User: user}
	if user.AvatarKey == nil {
		return p, nil
	}
	u, err := store.PresignGet(ctx, *user.AvatarKey)
	if err != nil {
		return Profile{}, err
	}
	p.AvatarURL = &u
	return p, nil
}

// ProfileService serves the signed-in user's own account: profile, avatar,
// settings, push token and devices (features 6, 7, 10–13).
type ProfileService struct {
	tx        *repository.TxManager
	users     *repository.UserRepository
	sessions  *repository.SessionRepository
	store     storage.Storage
	clock     clock.Clock
	log       *slog.Logger
	maxUpload int
}

func NewProfileService(
	tx *repository.TxManager,
	users *repository.UserRepository,
	sessions *repository.SessionRepository,
	store storage.Storage,
	clk clock.Clock,
	log *slog.Logger,
	cfg *config.Config,
) *ProfileService {
	return &ProfileService{
		tx: tx, users: users, sessions: sessions, store: store, clock: clk, log: log,
		maxUpload: cfg.MinIO.UploadMaxBytes,
	}
}

// Me returns the signed-in user.
func (s *ProfileService) Me(ctx context.Context, userID uuid.UUID) (Profile, error) {
	user, err := currentUser(s.users.GetByID(ctx, userID))
	if err != nil {
		return Profile{}, err
	}
	return profileOf(ctx, s.store, user)
}

// UpdateProfile changes the display name, trimmed of surrounding whitespace,
// and the phone used for wa.me reminder links (FR-PROF-01). The phone is
// optional and unverified; c.SetPhone with a nil Phone clears it.
func (s *ProfileService) UpdateProfile(ctx context.Context, userID uuid.UUID, c repository.ProfileChange) (Profile, error) {
	if c.Name != nil {
		name := strings.TrimSpace(*c.Name)
		switch n := utf8.RuneCountInString(name); {
		case n < nameMinLen:
			return Profile{}, model.NewValidationError(model.FieldError{
				Field: "name", Code: model.FieldMinLength, Message: fmt.Sprintf("Must have at least %d characters.", nameMinLen),
			})
		case n > nameMaxLen:
			return Profile{}, model.NewValidationError(model.FieldError{
				Field: "name", Code: model.FieldMaxLength, Message: fmt.Sprintf("Must have at most %d characters.", nameMaxLen),
			})
		}
		c.Name = &name
	}
	if c.SetPhone {
		var err error
		if c.Phone, err = normalizeOptionalPhone(c.Phone); err != nil {
			return Profile{}, err
		}
	}
	user, err := currentUser(s.users.UpdateProfile(ctx, userID, c))
	if err != nil {
		return Profile{}, err
	}
	return profileOf(ctx, s.store, user)
}

// UploadAvatar checks data by content (JPEG, PNG or WebP, at most
// UPLOAD_MAX_BYTES), resizes and re-encodes it, stores it under a new key and
// then removes the previous avatar (FR-PROF-02).
func (s *ProfileService) UploadAvatar(ctx context.Context, userID uuid.UUID, data []byte) (Profile, error) {
	if len(data) > s.maxUpload {
		return Profile{}, model.ErrFileTooLarge
	}
	avatar, err := images.Avatar(data)
	if errors.Is(err, images.ErrUnsupported) {
		return Profile{}, model.ErrUnsupportedMediaType
	}
	if err != nil {
		return Profile{}, err
	}
	// A new key per upload, so a cached URL never shows the wrong picture.
	key := fmt.Sprintf("avatars/%s/%s.jpg", userID, uuid.Must(uuid.NewV7()))
	if err := s.store.Put(ctx, key, images.JPEG, bytes.NewReader(avatar), int64(len(avatar))); err != nil {
		return Profile{}, err
	}
	user, old, err := s.swapAvatar(ctx, userID, &key)
	if err != nil {
		s.deleteObject(ctx, key)
		return Profile{}, err
	}
	if old != nil {
		s.deleteObject(ctx, *old)
	}
	return profileOf(ctx, s.store, user)
}

// DeleteAvatar removes the avatar; the app shows initials instead. Having no
// avatar is not an error.
func (s *ProfileService) DeleteAvatar(ctx context.Context, userID uuid.UUID) error {
	_, old, err := s.swapAvatar(ctx, userID, nil)
	if err != nil {
		return err
	}
	if old != nil {
		s.deleteObject(ctx, *old)
	}
	return nil
}

// swapAvatar sets the user's avatar key under a row lock and returns the
// updated user and the key it replaced.
func (s *ProfileService) swapAvatar(ctx context.Context, userID uuid.UUID, key *string) (model.User, *string, error) {
	var user model.User
	var old *string
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		current, err := currentUser(s.users.GetByIDForUpdate(ctx, userID))
		if err != nil {
			return err
		}
		old = current.AvatarKey
		user, err = s.users.SetAvatarKey(ctx, userID, key)
		return err
	})
	return user, old, err
}

// deleteObject removes an object nothing points at any more. A failure only
// leaves an orphan behind, so it is logged rather than returned.
func (s *ProfileService) deleteObject(ctx context.Context, key string) {
	if err := s.store.Delete(context.WithoutCancel(ctx), key); err != nil {
		s.log.WarnContext(ctx, "orphaned storage object", "key", key, "error", err)
	}
}

// Settings returns the user's language and notification settings.
func (s *ProfileService) Settings(ctx context.Context, userID uuid.UUID) (model.UserSettings, error) {
	settings, err := s.users.GetSettings(ctx, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.UserSettings{}, model.ErrUnauthorized
	}
	return settings, err
}

// UpdateSettings changes the non-nil fields of c.
func (s *ProfileService) UpdateSettings(ctx context.Context, userID uuid.UUID, c repository.SettingsChange) (model.UserSettings, error) {
	settings, err := s.users.UpdateSettings(ctx, userID, c)
	if errors.Is(err, repository.ErrNotFound) {
		return model.UserSettings{}, model.ErrUnauthorized
	}
	return settings, err
}

// SetPushToken stores the device's FCM token on the current session. A
// revoked session is treated as unauthenticated.
func (s *ProfileService) SetPushToken(ctx context.Context, userID, sessionID uuid.UUID, token string) error {
	ok, err := s.sessions.SetFCMToken(ctx, sessionID, userID, token)
	if err != nil {
		return err
	}
	if !ok {
		return model.ErrUnauthorized
	}
	return nil
}

// ListSessions returns the user's signed-in devices, the current one first.
func (s *ProfileService) ListSessions(ctx context.Context, userID, sessionID uuid.UUID) ([]model.Session, error) {
	return s.sessions.ListActive(ctx, userID, sessionID, s.clock.Now())
}

// RevokeSession signs one of the user's devices out. An unknown, foreign or
// already revoked session is not_found.
func (s *ProfileService) RevokeSession(ctx context.Context, userID, sessionID uuid.UUID) error {
	ok, err := s.sessions.RevokeForUser(ctx, sessionID, userID, model.RevokedReasonSignedOutByUser, s.clock.Now())
	if err != nil {
		return err
	}
	if !ok {
		return model.ErrNotFound.WithDetail("Session not found.")
	}
	return nil
}

// currentUser maps a lookup of the signed-in user: a token for a user that no
// longer exists is treated as unauthenticated.
func currentUser(user model.User, err error) (model.User, error) {
	if errors.Is(err, repository.ErrNotFound) {
		return model.User{}, model.ErrUnauthorized
	}
	return user, err
}
