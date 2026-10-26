package controller

import (
	"context"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// AuthService is what AuthController needs from service.AuthService.
type AuthService interface {
	SignIn(ctx context.Context, idToken string, device service.Device) (service.SignInResult, error)
	Refresh(ctx context.Context, refreshToken string) (service.TokenPair, error)
	Logout(ctx context.Context, userID, sessionID uuid.UUID) error
	ChangePhone(ctx context.Context, userID, sessionID uuid.UUID, oldToken, newToken string) (service.Profile, error)
}

// AuthController serves /auth/sign-in, /auth/refresh, /auth/logout and
// /auth/phone.
type AuthController struct {
	auth AuthService
}

func NewAuthController(auth *service.AuthService) *AuthController {
	return &AuthController{auth: auth}
}

// SignIn handles POST /auth/sign-in.
func (h *AuthController) SignIn(c fiber.Ctx) error {
	var req dto.SignInRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	res, err := h.auth.SignIn(c.Context(), req.FirebaseIDToken, service.Device{
		Name:     req.DeviceName,
		Platform: model.DevicePlatform(req.DevicePlatform),
		FCMToken: req.FCMToken,
	})
	if err != nil {
		return err
	}
	return response.OK(c, dto.AuthResult{
		User:      dto.NewMe(res.Profile.User, res.Profile.AvatarURL),
		Tokens:    dto.NewTokenPair(res.Tokens.AccessToken, res.Tokens.RefreshToken, res.Tokens.ExpiresIn),
		IsNewUser: res.IsNewUser,
		PINSet:    res.Profile.User.HasPIN(),
	})
}

// Refresh handles POST /auth/refresh.
func (h *AuthController) Refresh(c fiber.Ctx) error {
	var req dto.RefreshRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	pair, err := h.auth.Refresh(c.Context(), req.RefreshToken)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewTokenPair(pair.AccessToken, pair.RefreshToken, pair.ExpiresIn))
}

// Logout handles POST /auth/logout.
func (h *AuthController) Logout(c fiber.Ctx) error {
	if err := h.auth.Logout(c.Context(), middleware.UserID(c), middleware.SessionID(c)); err != nil {
		return err
	}
	return response.NoContent(c)
}

// ChangePhone handles PUT /auth/phone.
func (h *AuthController) ChangePhone(c fiber.Ctx) error {
	var req dto.ChangePhoneRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	p, err := h.auth.ChangePhone(c.Context(), middleware.UserID(c), middleware.SessionID(c), req.OldFirebaseIDToken, req.NewFirebaseIDToken)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMe(p.User, p.AvatarURL))
}
