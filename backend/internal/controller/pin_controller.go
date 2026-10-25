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

// PINService is what PINController needs from service.PINService.
type PINService interface {
	Set(ctx context.Context, userID uuid.UUID, pin string) error
	Verify(ctx context.Context, userID uuid.UUID, pin string) error
	Change(ctx context.Context, userID uuid.UUID, currentPIN, newPIN string) error
	Reset(ctx context.Context, userID, sessionID uuid.UUID, idToken, newPIN string) error
}

// PINController serves /auth/pin, /auth/pin/verify and /auth/pin/reset.
// Every route is behind middleware.Auth.
type PINController struct {
	pin PINService
}

func NewPINController(pin *service.PINService) *PINController {
	return &PINController{pin: pin}
}

// Set handles POST /auth/pin.
func (h *PINController) Set(c fiber.Ctx) error {
	var req dto.SetPinRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	if err := h.pin.Set(c.Context(), middleware.UserID(c), req.PIN); err != nil {
		return err
	}
	return response.NoContent(c)
}

// Change handles PUT /auth/pin.
func (h *PINController) Change(c fiber.Ctx) error {
	var req dto.ChangePinRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	if err := h.pin.Change(c.Context(), middleware.UserID(c), req.CurrentPIN, req.NewPIN); err != nil {
		return err
	}
	return response.NoContent(c)
}

// Verify handles POST /auth/pin/verify.
func (h *PINController) Verify(c fiber.Ctx) error {
	var req dto.PinRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	if err := h.pin.Verify(c.Context(), middleware.UserID(c), req.PIN); err != nil {
		return err
	}
	return response.NoContent(c)
}

// Reset handles POST /auth/pin/reset.
func (h *PINController) Reset(c fiber.Ctx) error {
	var req dto.ResetPinRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	err := h.pin.Reset(c.Context(), middleware.UserID(c), middleware.SessionID(c), req.FirebaseIDToken, req.NewPIN)
	if err != nil {
		return err
	}
	return response.NoContent(c)
}
