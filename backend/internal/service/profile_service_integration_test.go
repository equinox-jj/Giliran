//go:build integration

package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

type profileEnv struct {
	authEnv
	svc *ProfileService
}

func newProfileEnv(t *testing.T) profileEnv {
	t.Helper()
	auth := newAuthEnv(t, fakeVerifier{"tok": rina, "budi": budi})
	tx := repository.NewTxManager(auth.pool)
	svc := NewProfileService(repository.NewUserRepository(tx), repository.NewSessionRepository(tx), auth.clock)
	return profileEnv{authEnv: auth, svc: svc}
}

// session signs in with idToken and returns the user and session IDs.
func (e profileEnv) session(t *testing.T, idToken string) (uuid.UUID, uuid.UUID) {
	t.Helper()
	res := e.signIn(t, idToken)
	userID, sessionID, err := e.tokens.Parse(res.Tokens.AccessToken)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	return userID, sessionID
}

func TestProfileUpdateNameTrims(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")

	// Act
	user, err := env.svc.UpdateName(context.Background(), userID, "  Rina Susanti ")

	// Assert
	if err != nil || user.Name == nil || *user.Name != "Rina Susanti" {
		t.Fatalf("UpdateName: %v, name %v", err, user.Name)
	}
}

func TestProfileUpdateNameRejectsBlank(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")

	// Act
	_, err := env.svc.UpdateName(context.Background(), userID, "  R  ")

	// Assert
	if !errors.Is(err, model.ErrValidation) {
		t.Errorf("err %v, want validation_error", err)
	}
}

func TestProfileUpdateSettingsKeepsOtherFields(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")
	off := false

	// Act
	settings, err := env.svc.UpdateSettings(context.Background(), userID, repository.SettingsChange{NotifyDrawResults: &off})

	// Assert
	if err != nil {
		t.Fatalf("UpdateSettings: %v", err)
	}
	if settings.NotifyDrawResults || !settings.NotifyPaymentReminders || !settings.NotifyGroupActivity || settings.Language != model.LanguageIndonesian {
		t.Errorf("settings %+v", settings)
	}
}

func TestProfileSetPushToken(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, sessionID := env.session(t, "tok")

	// Act
	err := env.svc.SetPushToken(context.Background(), userID, sessionID, "fcm-new")

	// Assert
	if err != nil {
		t.Fatalf("SetPushToken: %v", err)
	}
	if n := env.count(t, `SELECT count(*) FROM sessions WHERE id = $1 AND fcm_token = 'fcm-new'`, sessionID); n != 1 {
		t.Error("token not stored")
	}
}

func TestProfileSetPushTokenOnRevokedSession(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, sessionID := env.session(t, "tok")
	if err := env.svc.RevokeSession(context.Background(), userID, sessionID); err != nil {
		t.Fatalf("RevokeSession: %v", err)
	}

	// Act
	err := env.svc.SetPushToken(context.Background(), userID, sessionID, "fcm-new")

	// Assert
	if !errors.Is(err, model.ErrUnauthorized) {
		t.Errorf("err %v, want unauthorized", err)
	}
}

func TestProfileListSessions(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, current := env.session(t, "tok")
	env.clock.Advance(time.Minute)
	_, newer := env.session(t, "tok")
	_, revoked := env.session(t, "tok")
	if err := env.svc.RevokeSession(context.Background(), userID, revoked); err != nil {
		t.Fatalf("RevokeSession: %v", err)
	}
	_, expired := env.session(t, "tok")
	if _, err := env.pool.Exec(context.Background(), `UPDATE sessions SET expires_at = $2 WHERE id = $1`, expired, env.clock.Now()); err != nil {
		t.Fatalf("expire session: %v", err)
	}
	env.session(t, "budi")

	// Act
	sessions, err := env.svc.ListSessions(context.Background(), userID, current)

	// Assert
	if err != nil {
		t.Fatalf("ListSessions: %v", err)
	}
	if len(sessions) != 2 || sessions[0].ID != current || sessions[1].ID != newer {
		t.Errorf("sessions %v, want [%s %s]", sessions, current, newer)
	}
}

func TestProfileRevokeSession(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")
	_, other := env.session(t, "tok")

	// Act
	err := env.svc.RevokeSession(context.Background(), userID, other)

	// Assert
	if err != nil {
		t.Fatalf("RevokeSession: %v", err)
	}
	if n := env.count(t, `SELECT count(*) FROM sessions WHERE id = $1 AND revoked_reason = 'signed_out_by_user'`, other); n != 1 {
		t.Error("session not revoked as signed_out_by_user")
	}
}

func TestProfileRevokeOtherUsersSession(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")
	_, budiSession := env.session(t, "budi")

	// Act
	err := env.svc.RevokeSession(context.Background(), userID, budiSession)

	// Assert
	if !errors.Is(err, model.ErrNotFound) {
		t.Errorf("err %v, want not_found", err)
	}
	if n := env.count(t, `SELECT count(*) FROM sessions WHERE id = $1 AND revoked_at IS NULL`, budiSession); n != 1 {
		t.Error("another user's session was revoked")
	}
}
