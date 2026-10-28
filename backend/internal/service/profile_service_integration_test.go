//go:build integration

package service

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/jpeg"
	"io"
	"log/slog"
	"maps"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// memStore is an in-memory storage.Storage. Presigned URLs are the key
// behind a fake origin.
type memStore struct {
	mu      sync.Mutex
	objects map[string][]byte
	putErr  error
}

func newMemStore() *memStore {
	return &memStore{objects: map[string][]byte{}}
}

func (m *memStore) Put(_ context.Context, key, _ string, r io.Reader, _ int64) error {
	if m.putErr != nil {
		return m.putErr
	}
	data, err := io.ReadAll(r)
	if err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.objects[key] = data
	return nil
}

func (m *memStore) Delete(_ context.Context, key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.objects, key)
	return nil
}

func (m *memStore) PresignGet(_ context.Context, key string) (string, error) {
	return "https://files.test/" + key, nil
}

func (m *memStore) keys() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return slices.Sorted(maps.Keys(m.objects))
}

type profileEnv struct {
	authEnv
	svc   *ProfileService
	store *memStore
}

func newProfileEnv(t *testing.T) profileEnv {
	t.Helper()
	auth := newAuthEnv(t, accounts{"tok": rina, "budi": budi})
	tx := repository.NewTxManager(auth.pool)
	store := newMemStore()
	cfg := &config.Config{MinIO: config.MinIO{UploadMaxBytes: 5 << 20}}
	svc := NewProfileService(tx, repository.NewUserRepository(tx), repository.NewSessionRepository(tx), store,
		auth.clock, slog.New(slog.NewTextHandler(io.Discard, nil)), cfg)
	return profileEnv{authEnv: auth, svc: svc, store: store}
}

func testJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, image.NewRGBA(image.Rect(0, 0, w, h)), nil); err != nil {
		t.Fatalf("jpeg.Encode: %v", err)
	}
	return buf.Bytes()
}

// session signs the account under key in and returns the user and session IDs.
func (e profileEnv) session(t *testing.T, key string) (uuid.UUID, uuid.UUID) {
	t.Helper()
	res := e.signIn(t, key)
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
	name := "  Rina Susanti "

	// Act
	user, err := env.svc.UpdateProfile(context.Background(), userID, repository.ProfileChange{Name: &name})

	// Assert
	if err != nil || user.User.Name == nil || *user.User.Name != "Rina Susanti" {
		t.Fatalf("UpdateProfile: %v, name %v", err, user.User.Name)
	}
	if user.User.Phone == nil || *user.User.Phone != rina.Phone {
		t.Errorf("phone %v, want it kept as %s", user.User.Phone, rina.Phone)
	}
}

func TestProfileUpdatePhone(t *testing.T) {
	// Arrange
	t.Parallel()
	local := "0813-1111-2222"
	want := "+6281311112222"
	tests := []struct {
		name  string
		phone *string
		want  *string
	}{
		{"normalized", &local, &want},
		{"cleared", nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newProfileEnv(t)
			userID, _ := env.session(t, "tok")

			// Act
			user, err := env.svc.UpdateProfile(context.Background(), userID, repository.ProfileChange{SetPhone: true, Phone: tt.phone})

			// Assert
			if err != nil {
				t.Fatalf("UpdateProfile: %v", err)
			}
			if (user.User.Phone == nil) != (tt.want == nil) || tt.want != nil && *user.User.Phone != *tt.want {
				t.Errorf("phone %v, want %v", user.User.Phone, tt.want)
			}
			if user.User.Name != nil {
				t.Errorf("name %v, want it left unset", *user.User.Name)
			}
		})
	}
}

func TestProfileUpdateRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	blank, foreign := "  R  ", "+6591234567"
	tests := []struct {
		name   string
		change repository.ProfileChange
		field  string
	}{
		{"blank name", repository.ProfileChange{Name: &blank}, "name"},
		{"non-Indonesian phone", repository.ProfileChange{SetPhone: true, Phone: &foreign}, "phone"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newProfileEnv(t)
			userID, _ := env.session(t, "tok")

			// Act
			_, err := env.svc.UpdateProfile(context.Background(), userID, tt.change)

			// Assert
			var merr *model.Error
			if !errors.As(err, &merr) || merr.Code != "validation_error" || len(merr.Fields) != 1 || merr.Fields[0].Field != tt.field {
				t.Errorf("err %v, want validation_error on %s", err, tt.field)
			}
		})
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

func TestProfileUploadAvatar(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")

	// Act
	p, err := env.svc.UploadAvatar(context.Background(), userID, testJPEG(t, 1024, 1024))

	// Assert
	if err != nil {
		t.Fatalf("UploadAvatar: %v", err)
	}
	keys := env.store.keys()
	if len(keys) != 1 || !strings.HasPrefix(keys[0], "avatars/"+userID.String()+"/") {
		t.Fatalf("stored keys %v", keys)
	}
	if p.User.AvatarKey == nil || *p.User.AvatarKey != keys[0] || p.AvatarURL == nil || *p.AvatarURL != "https://files.test/"+keys[0] {
		t.Errorf("profile key %v url %v", p.User.AvatarKey, p.AvatarURL)
	}
	if cfg, err := jpeg.DecodeConfig(bytes.NewReader(env.store.objects[keys[0]])); err != nil || cfg.Width != 512 {
		t.Errorf("stored image %v, width %d, want 512", err, cfg.Width)
	}
}

func TestProfileUploadAvatarReplacesOld(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")
	first, err := env.svc.UploadAvatar(context.Background(), userID, testJPEG(t, 64, 64))
	if err != nil {
		t.Fatalf("first UploadAvatar: %v", err)
	}

	// Act
	second, err := env.svc.UploadAvatar(context.Background(), userID, testJPEG(t, 64, 64))

	// Assert
	if err != nil {
		t.Fatalf("second UploadAvatar: %v", err)
	}
	if keys := env.store.keys(); len(keys) != 1 || keys[0] != *second.User.AvatarKey || keys[0] == *first.User.AvatarKey {
		t.Errorf("stored keys %v, want only %s", keys, *second.User.AvatarKey)
	}
}

func TestProfileUploadAvatarRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name string
		data []byte
		want error
	}{
		{"not an image", []byte("%PDF-1.7 not a picture"), model.ErrUnsupportedMediaType},
		{"over the limit", make([]byte, 5<<20+1), model.ErrFileTooLarge},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newProfileEnv(t)
			userID, _ := env.session(t, "tok")

			// Act
			_, err := env.svc.UploadAvatar(context.Background(), userID, tt.data)

			// Assert
			if !errors.Is(err, tt.want) {
				t.Errorf("err %v, want %v", err, tt.want)
			}
			if keys := env.store.keys(); len(keys) != 0 {
				t.Errorf("stored %v", keys)
			}
		})
	}
}

func TestProfileUploadAvatarStorageFailureKeepsOld(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")
	first, err := env.svc.UploadAvatar(context.Background(), userID, testJPEG(t, 64, 64))
	if err != nil {
		t.Fatalf("first UploadAvatar: %v", err)
	}
	env.store.putErr = errors.New("minio down")

	// Act
	_, err = env.svc.UploadAvatar(context.Background(), userID, testJPEG(t, 64, 64))

	// Assert
	if err == nil {
		t.Fatal("UploadAvatar succeeded with storage down")
	}
	me, err := env.svc.Me(context.Background(), userID)
	if err != nil || me.User.AvatarKey == nil || *me.User.AvatarKey != *first.User.AvatarKey {
		t.Errorf("avatar key %v after failed upload, want %s", me.User.AvatarKey, *first.User.AvatarKey)
	}
}

func TestProfileDeleteAvatar(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")
	if _, err := env.svc.UploadAvatar(context.Background(), userID, testJPEG(t, 64, 64)); err != nil {
		t.Fatalf("UploadAvatar: %v", err)
	}

	// Act
	err := env.svc.DeleteAvatar(context.Background(), userID)

	// Assert
	if err != nil {
		t.Fatalf("DeleteAvatar: %v", err)
	}
	me, err := env.svc.Me(context.Background(), userID)
	if err != nil || me.User.AvatarKey != nil || me.AvatarURL != nil {
		t.Errorf("after delete: %v, key %v url %v", err, me.User.AvatarKey, me.AvatarURL)
	}
	if keys := env.store.keys(); len(keys) != 0 {
		t.Errorf("objects left %v", keys)
	}
}

func TestProfileDeleteAvatarWithoutOne(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newProfileEnv(t)
	userID, _ := env.session(t, "tok")

	// Act
	err := env.svc.DeleteAvatar(context.Background(), userID)

	// Assert
	if err != nil {
		t.Errorf("DeleteAvatar: %v", err)
	}
}
