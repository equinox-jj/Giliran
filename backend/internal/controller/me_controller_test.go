package controller

import (
	"bytes"
	"context"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

// fakeProfile records its inputs and returns canned results.
type fakeProfile struct {
	profile  service.Profile
	settings model.UserSettings
	sessions []model.Session
	err      error

	called     string
	gotUser    uuid.UUID
	gotSession uuid.UUID
	gotName    string
	gotToken   string
	gotData    []byte
	gotChange  repository.SettingsChange
}

func (f *fakeProfile) Me(_ context.Context, userID uuid.UUID) (service.Profile, error) {
	f.called, f.gotUser = "me", userID
	return f.profile, f.err
}

func (f *fakeProfile) UpdateName(_ context.Context, userID uuid.UUID, name string) (service.Profile, error) {
	f.called, f.gotUser, f.gotName = "update_name", userID, name
	return f.profile, f.err
}

func (f *fakeProfile) UploadAvatar(_ context.Context, userID uuid.UUID, data []byte) (service.Profile, error) {
	f.called, f.gotUser, f.gotData = "upload_avatar", userID, data
	return f.profile, f.err
}

func (f *fakeProfile) DeleteAvatar(_ context.Context, userID uuid.UUID) error {
	f.called, f.gotUser = "delete_avatar", userID
	return f.err
}

func (f *fakeProfile) Settings(_ context.Context, userID uuid.UUID) (model.UserSettings, error) {
	f.called, f.gotUser = "settings", userID
	return f.settings, f.err
}

func (f *fakeProfile) UpdateSettings(_ context.Context, userID uuid.UUID, c repository.SettingsChange) (model.UserSettings, error) {
	f.called, f.gotUser, f.gotChange = "update_settings", userID, c
	return f.settings, f.err
}

func (f *fakeProfile) SetPushToken(_ context.Context, userID, sessionID uuid.UUID, token string) error {
	f.called, f.gotUser, f.gotSession, f.gotToken = "push_token", userID, sessionID, token
	return f.err
}

func (f *fakeProfile) ListSessions(_ context.Context, userID, sessionID uuid.UUID) ([]model.Session, error) {
	f.called, f.gotUser, f.gotSession = "list_sessions", userID, sessionID
	return f.sessions, f.err
}

func (f *fakeProfile) RevokeSession(_ context.Context, userID, sessionID uuid.UUID) error {
	f.called, f.gotUser, f.gotSession = "revoke_session", userID, sessionID
	return f.err
}

// newMeApp mounts the /me routes as routes.Register does, minus rate limits.
func newMeApp(profile ProfileService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &MeController{profile: profile}
	me := app.Group("/api/v1/me", middleware.Auth(testTokens))
	me.Get("", h.Get)
	me.Patch("", h.Update)
	me.Put("/avatar", h.UploadAvatar)
	me.Delete("/avatar", h.DeleteAvatar)
	me.Get("/settings", h.GetSettings)
	me.Patch("/settings", h.UpdateSettings)
	me.Put("/push-token", h.SetPushToken)
	me.Get("/sessions", h.ListSessions)
	me.Delete("/sessions/:session_id", h.RevokeSession)
	return app
}

func testSettings() model.UserSettings {
	s := model.NewUserSettings(uuid.Must(uuid.NewV7()))
	s.Language = model.LanguageEnglish
	return s
}

func TestMeGet(t *testing.T) {
	// Arrange
	name := "Rina Susanti"
	fake := &fakeProfile{profile: service.Profile{User: model.User{ID: uuid.Must(uuid.NewV7()), Phone: "+6281234567890", Name: &name, CreatedAt: time.Now()}}}
	req, userID, _ := authed(t, http.MethodGet, "/api/v1/me", "")

	// Act
	resp, body := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "me" || fake.gotUser != userID {
		t.Fatalf("status %d, service got %s for %s", resp.StatusCode, fake.called, fake.gotUser)
	}
	if data := body["data"].(map[string]any); data["name"] != name || data["avatar_url"] != nil || data["pin_set"] != false {
		t.Errorf("data %v", data)
	}
}

func TestMeUpdate(t *testing.T) {
	// Arrange
	fake := &fakeProfile{profile: service.Profile{User: model.User{ID: uuid.Must(uuid.NewV7()), Phone: "+6281234567890", CreatedAt: time.Now()}}}
	req, _, _ := authed(t, http.MethodPatch, "/api/v1/me", `{"name":"Rina"}`)

	// Act
	resp, _ := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "update_name" || fake.gotName != "Rina" {
		t.Errorf("status %d, service got %s %q", resp.StatusCode, fake.called, fake.gotName)
	}
}

// avatarRequest builds an authorized multipart PUT /me/avatar with data in
// the field named field.
func avatarRequest(t *testing.T, field string, data []byte) (*http.Request, uuid.UUID) {
	t.Helper()
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	part, err := w.CreateFormFile(field, "avatar.jpg")
	if err != nil {
		t.Fatalf("CreateFormFile: %v", err)
	}
	part.Write(data)
	w.Close()
	userID, sessionID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	token, _, err := testTokens.Issue(userID, sessionID)
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	req := httptest.NewRequest(http.MethodPut, "/api/v1/me/avatar", &body)
	req.Header.Set(fiber.HeaderContentType, w.FormDataContentType())
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
	return req, userID
}

func TestMeUploadAvatar(t *testing.T) {
	// Arrange
	url := "http://localhost:9000/giliran/avatars/a.jpg?X-Amz-Signature=x"
	fake := &fakeProfile{profile: service.Profile{
		User:      model.User{ID: uuid.Must(uuid.NewV7()), Phone: "+6281234567890", CreatedAt: time.Now()},
		AvatarURL: &url,
	}}
	req, userID := avatarRequest(t, "file", []byte("image bytes"))

	// Act
	resp, body := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "upload_avatar" || fake.gotUser != userID || string(fake.gotData) != "image bytes" {
		t.Fatalf("status %d, service got %s for %s with %q", resp.StatusCode, fake.called, fake.gotUser, fake.gotData)
	}
	if data := body["data"].(map[string]any); data["avatar_url"] != url {
		t.Errorf("avatar_url %v, want %s", data["avatar_url"], url)
	}
}

func TestMeUploadAvatarErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		field      string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"missing file field", "photo", nil, 422, "validation_error"},
		{"too large", "file", model.ErrFileTooLarge, 413, "file_too_large"},
		{"not an image", "file", model.ErrUnsupportedMediaType, 415, "unsupported_media_type"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req, _ := avatarRequest(t, tt.field, []byte("data"))

			// Act
			resp, body := call(t, newMeApp(&fakeProfile{err: tt.serviceErr}), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestMeUploadAvatarRequiresMultipart(t *testing.T) {
	// Arrange
	req, _, _ := authed(t, http.MethodPut, "/api/v1/me/avatar", `{"file":"x"}`)

	// Act
	resp, body := call(t, newMeApp(&fakeProfile{}), req)

	// Assert
	if resp.StatusCode != 415 || body["code"] != "unsupported_media_type" {
		t.Errorf("status %d code %v, want 415 unsupported_media_type", resp.StatusCode, body["code"])
	}
}

func TestMeDeleteAvatar(t *testing.T) {
	// Arrange
	fake := &fakeProfile{}
	req, userID, _ := authed(t, http.MethodDelete, "/api/v1/me/avatar", "")

	// Act
	resp, _ := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 204 || fake.called != "delete_avatar" || fake.gotUser != userID {
		t.Errorf("status %d, service got %s for %s", resp.StatusCode, fake.called, fake.gotUser)
	}
}

func TestMeSettings(t *testing.T) {
	// Arrange
	fake := &fakeProfile{settings: testSettings()}
	req, _, _ := authed(t, http.MethodGet, "/api/v1/me/settings", "")

	// Act
	resp, body := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d, body %v", resp.StatusCode, body)
	}
	if data := body["data"].(map[string]any); data["language"] != "en" || data["notify_draw_results"] != true {
		t.Errorf("data %v", data)
	}
}

func TestMeUpdateSettings(t *testing.T) {
	// Arrange
	fake := &fakeProfile{settings: testSettings()}
	req, _, _ := authed(t, http.MethodPatch, "/api/v1/me/settings", `{"language":"en","notify_group_activity":false}`)

	// Act
	resp, _ := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d, want 200", resp.StatusCode)
	}
	c := fake.gotChange
	if c.Language == nil || *c.Language != model.LanguageEnglish || c.NotifyGroupActivity == nil || *c.NotifyGroupActivity ||
		c.NotifyPaymentReminders != nil || c.NotifyDrawResults != nil {
		t.Errorf("service got %+v", c)
	}
}

func TestMeSetPushToken(t *testing.T) {
	// Arrange
	fake := &fakeProfile{}
	req, userID, sessionID := authed(t, http.MethodPut, "/api/v1/me/push-token", `{"fcm_token":"fcm-1"}`)

	// Act
	resp, _ := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 204 || fake.gotUser != userID || fake.gotSession != sessionID || fake.gotToken != "fcm-1" {
		t.Errorf("status %d, service got %s/%s %q", resp.StatusCode, fake.gotUser, fake.gotSession, fake.gotToken)
	}
}

func TestMeListSessions(t *testing.T) {
	// Arrange
	req, _, sessionID := authed(t, http.MethodGet, "/api/v1/me/sessions", "")
	device := "Samsung Galaxy A54"
	now := time.Now()
	fake := &fakeProfile{sessions: []model.Session{
		{ID: sessionID, DeviceName: &device, DevicePlatform: model.DevicePlatformAndroid, LastActiveAt: now, CreatedAt: now},
		{ID: uuid.Must(uuid.NewV7()), DevicePlatform: model.DevicePlatformIOS, LastActiveAt: now, CreatedAt: now},
	}}

	// Act
	resp, body := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotSession != sessionID {
		t.Fatalf("status %d, service got session %s", resp.StatusCode, fake.gotSession)
	}
	data := body["data"].([]any)
	if len(data) != 2 || data[0].(map[string]any)["is_current"] != true || data[1].(map[string]any)["is_current"] != false {
		t.Errorf("data %v", data)
	}
}

func TestMeListSessionsEmpty(t *testing.T) {
	// Arrange
	req, _, _ := authed(t, http.MethodGet, "/api/v1/me/sessions", "")

	// Act
	resp, body := call(t, newMeApp(&fakeProfile{sessions: []model.Session{}}), req)

	// Assert
	if data, ok := body["data"].([]any); resp.StatusCode != 200 || !ok || len(data) != 0 {
		t.Errorf("status %d data %v, want 200 []", resp.StatusCode, body["data"])
	}
}

func TestMeRevokeSession(t *testing.T) {
	// Arrange
	fake := &fakeProfile{}
	target := uuid.Must(uuid.NewV7())
	req, userID, _ := authed(t, http.MethodDelete, "/api/v1/me/sessions/"+target.String(), "")

	// Act
	resp, _ := call(t, newMeApp(fake), req)

	// Assert
	if resp.StatusCode != 204 || fake.gotUser != userID || fake.gotSession != target {
		t.Errorf("status %d, service got %s/%s", resp.StatusCode, fake.gotUser, fake.gotSession)
	}
}

func TestMeErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		method     string
		path       string
		body       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"name too short", http.MethodPatch, "/api/v1/me", `{"name":"R"}`, nil, 422, "validation_error"},
		{"name missing", http.MethodPatch, "/api/v1/me", `{}`, nil, 422, "validation_error"},
		{"settings empty", http.MethodPatch, "/api/v1/me/settings", `{}`, nil, 422, "validation_error"},
		{"settings bad language", http.MethodPatch, "/api/v1/me/settings", `{"language":"fr"}`, nil, 422, "validation_error"},
		{"push token missing", http.MethodPut, "/api/v1/me/push-token", `{}`, nil, 422, "validation_error"},
		{"revoke unknown session", http.MethodDelete, "/api/v1/me/sessions/" + uuid.NewString(), "", model.ErrNotFound, 404, "not_found"},
		{"revoke malformed id", http.MethodDelete, "/api/v1/me/sessions/not-a-uuid", "", nil, 404, "not_found"},
		{"deleted user", http.MethodGet, "/api/v1/me", "", model.ErrUnauthorized, 401, "unauthorized"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req, _, _ := authed(t, tt.method, tt.path, tt.body)

			// Act
			resp, body := call(t, newMeApp(&fakeProfile{err: tt.serviceErr}), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestMeRequiresToken(t *testing.T) {
	// Arrange
	req := jsonRequest("/api/v1/me", "")
	req.Method = http.MethodGet

	// Act
	resp, body := call(t, newMeApp(&fakeProfile{}), req)

	// Assert
	if resp.StatusCode != 401 || body["code"] != "unauthorized" {
		t.Errorf("status %d code %v, want 401 unauthorized", resp.StatusCode, body["code"])
	}
}
