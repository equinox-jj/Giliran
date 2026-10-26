package controller

import (
	"context"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// ProfileService is what MeController needs from service.ProfileService.
type ProfileService interface {
	Me(ctx context.Context, userID uuid.UUID) (service.Profile, error)
	UpdateName(ctx context.Context, userID uuid.UUID, name string) (service.Profile, error)
	UploadAvatar(ctx context.Context, userID uuid.UUID, data []byte) (service.Profile, error)
	DeleteAvatar(ctx context.Context, userID uuid.UUID) error
	Settings(ctx context.Context, userID uuid.UUID) (model.UserSettings, error)
	UpdateSettings(ctx context.Context, userID uuid.UUID, c repository.SettingsChange) (model.UserSettings, error)
	SetPushToken(ctx context.Context, userID, sessionID uuid.UUID, token string) error
	ListSessions(ctx context.Context, userID, sessionID uuid.UUID) ([]model.Session, error)
	RevokeSession(ctx context.Context, userID, sessionID uuid.UUID) error
}

// MeController serves /me, /me/avatar, /me/settings, /me/push-token and
// /me/sessions.
// Every route is behind middleware.Auth.
type MeController struct {
	profile ProfileService
}

func NewMeController(profile *service.ProfileService) *MeController {
	return &MeController{profile: profile}
}

// Get handles GET /me.
func (h *MeController) Get(c fiber.Ctx) error {
	p, err := h.profile.Me(c.Context(), middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMe(p.User, p.AvatarURL))
}

// Update handles PATCH /me.
func (h *MeController) Update(c fiber.Ctx) error {
	var req dto.UpdateMeRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	p, err := h.profile.UpdateName(c.Context(), middleware.UserID(c), req.Name)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMe(p.User, p.AvatarURL))
}

// UploadAvatar handles PUT /me/avatar (multipart field "file"). The service
// checks the type by content; the declared type is ignored.
func (h *MeController) UploadAvatar(c fiber.Ctx) error {
	data, err := readUpload(c)
	if err != nil {
		return err
	}
	p, err := h.profile.UploadAvatar(c.Context(), middleware.UserID(c), data)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMe(p.User, p.AvatarURL))
}

// DeleteAvatar handles DELETE /me/avatar.
func (h *MeController) DeleteAvatar(c fiber.Ctx) error {
	if err := h.profile.DeleteAvatar(c.Context(), middleware.UserID(c)); err != nil {
		return err
	}
	return response.NoContent(c)
}

// GetSettings handles GET /me/settings.
func (h *MeController) GetSettings(c fiber.Ctx) error {
	settings, err := h.profile.Settings(c.Context(), middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewUserSettings(settings))
}

// UpdateSettings handles PATCH /me/settings.
func (h *MeController) UpdateSettings(c fiber.Ctx) error {
	var req dto.UpdateSettingsRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	if req.IsEmpty() {
		return model.ErrValidation.WithDetail("Send at least one setting to change.")
	}
	change := repository.SettingsChange{
		NotifyPaymentReminders: req.NotifyPaymentReminders,
		NotifyDrawResults:      req.NotifyDrawResults,
		NotifyGroupActivity:    req.NotifyGroupActivity,
	}
	if req.Language != nil {
		lang := model.Language(*req.Language)
		change.Language = &lang
	}
	settings, err := h.profile.UpdateSettings(c.Context(), middleware.UserID(c), change)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewUserSettings(settings))
}

// SetPushToken handles PUT /me/push-token.
func (h *MeController) SetPushToken(c fiber.Ctx) error {
	var req dto.PushTokenRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	if err := h.profile.SetPushToken(c.Context(), middleware.UserID(c), middleware.SessionID(c), req.FCMToken); err != nil {
		return err
	}
	return response.NoContent(c)
}

// ListSessions handles GET /me/sessions.
func (h *MeController) ListSessions(c fiber.Ctx) error {
	current := middleware.SessionID(c)
	sessions, err := h.profile.ListSessions(c.Context(), middleware.UserID(c), current)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewSessions(sessions, current))
}

// RevokeSession handles DELETE /me/sessions/{session_id}.
func (h *MeController) RevokeSession(c fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("session_id"))
	if err != nil {
		return model.ErrNotFound.WithDetail("Session not found.")
	}
	if err := h.profile.RevokeSession(c.Context(), middleware.UserID(c), id); err != nil {
		return err
	}
	return response.NoContent(c)
}
