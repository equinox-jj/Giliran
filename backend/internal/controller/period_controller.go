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

// PeriodService is what PeriodController needs from service.PeriodService.
type PeriodService interface {
	List(ctx context.Context, groupID, userID uuid.UUID) ([]service.PeriodDetail, error)
	Get(ctx context.Context, groupID, periodID, userID uuid.UUID) (service.PeriodDetail, error)
}

// PeriodController serves /groups/{group_id}/periods. Every route is behind
// middleware.Auth.
type PeriodController struct {
	periods PeriodService
}

func NewPeriodController(periods *service.PeriodService) *PeriodController {
	return &PeriodController{periods: periods}
}

// List handles GET /groups/{group_id}/periods.
func (h *PeriodController) List(c fiber.Ctx) error {
	gid, err := groupID(c)
	if err != nil {
		return err
	}
	periods, err := h.periods.List(c.Context(), gid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.List(c, dto.NewPeriods(periods), nil)
}

// Get handles GET /groups/{group_id}/periods/{period_id}.
func (h *PeriodController) Get(c fiber.Ctx) error {
	gid, err := groupID(c)
	if err != nil {
		return err
	}
	pid, err := periodID(c)
	if err != nil {
		return err
	}
	p, err := h.periods.Get(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPeriod(p))
}
