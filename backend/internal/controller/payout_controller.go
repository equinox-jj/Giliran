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

// PayoutService is what PayoutController needs from service.PayoutService.
type PayoutService interface {
	Get(ctx context.Context, groupID, periodID, userID uuid.UUID) (service.PayoutView, error)
	Record(ctx context.Context, groupID, periodID, userID uuid.UUID, proof []byte, note *string) (service.PayoutView, error)
	Confirm(ctx context.Context, groupID, periodID, userID uuid.UUID) (service.PayoutView, error)
}

// PayoutController serves a period's payout. Every route is behind
// middleware.Auth, and the writes behind Idempotency.
type PayoutController struct {
	payouts PayoutService
}

func NewPayoutController(payouts *service.PayoutService) *PayoutController {
	return &PayoutController{payouts: payouts}
}

// Get handles GET /groups/{group_id}/periods/{period_id}/payout.
func (h *PayoutController) Get(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	v, err := h.payouts.Get(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPayout(v))
}

// Record handles POST /groups/{group_id}/periods/{period_id}/payout
// (multipart: optional "file" and "note").
func (h *PayoutController) Record(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	proof, err := readOptionalUpload(c)
	if err != nil {
		return err
	}
	var note *string
	if form, err := c.MultipartForm(); err == nil {
		if vs := form.Value["note"]; len(vs) > 0 {
			note = &vs[0]
		}
	}
	v, err := h.payouts.Record(c.Context(), gid, pid, middleware.UserID(c), proof, note)
	if err != nil {
		return err
	}
	return response.Created(c, "/api/v1/groups/"+gid.String()+"/periods/"+pid.String()+"/payout", dto.NewPayout(v))
}

// Confirm handles POST /groups/{group_id}/periods/{period_id}/payout/confirm.
func (h *PayoutController) Confirm(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	v, err := h.payouts.Confirm(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPayout(v))
}
