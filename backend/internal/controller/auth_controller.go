package controller

import (
	"context"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// AuthService is what AuthController needs from service.AuthService.
type AuthService interface {
	Refresh(ctx context.Context, refreshToken string) (service.TokenPair, error)
	Logout(ctx context.Context, userID, sessionID uuid.UUID) error
}

// AuthController serves /auth/refresh and /auth/logout. Signing in is
// OTPController's.
type AuthController struct {
	auth AuthService
}

func NewAuthController(auth *service.AuthService) *AuthController {
	return &AuthController{auth: auth}
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
