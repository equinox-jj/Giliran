package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// Display name length limits (users.name CHECK).
const (
	nameMinLen = 2
	nameMaxLen = 50
)

// ProfileService serves the signed-in user's own account: profile, settings,
// push token and devices (features 6, 7, 10–13).
type ProfileService struct {
	users    *repository.UserRepository
	sessions *repository.SessionRepository
	clock    clock.Clock
}

func NewProfileService(users *repository.UserRepository, sessions *repository.SessionRepository, clk clock.Clock) *ProfileService {
	return &ProfileService{users: users, sessions: sessions, clock: clk}
}

// Me returns the signed-in user.
func (s *ProfileService) Me(ctx context.Context, userID uuid.UUID) (model.User, error) {
	return currentUser(s.users.GetByID(ctx, userID))
}

// UpdateName sets the display name, trimmed of surrounding whitespace.
func (s *ProfileService) UpdateName(ctx context.Context, userID uuid.UUID, name string) (model.User, error) {
	name = strings.TrimSpace(name)
	switch n := utf8.RuneCountInString(name); {
	case n < nameMinLen:
		return model.User{}, model.NewValidationError(model.FieldError{
			Field: "name", Code: model.FieldMinLength, Message: fmt.Sprintf("Must have at least %d characters.", nameMinLen),
		})
	case n > nameMaxLen:
		return model.User{}, model.NewValidationError(model.FieldError{
			Field: "name", Code: model.FieldMaxLength, Message: fmt.Sprintf("Must have at most %d characters.", nameMaxLen),
		})
	}
	return currentUser(s.users.UpdateName(ctx, userID, name))
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
