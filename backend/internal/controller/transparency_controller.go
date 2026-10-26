package controller

import (
	"context"
	"strconv"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// TransparencyService is what TransparencyController needs from
// service.TransparencyService.
type TransparencyService interface {
	Activity(ctx context.Context, groupID, userID uuid.UUID, cursor string, limit int) (service.ActivityPage, error)
	Obligations(ctx context.Context, groupID, userID uuid.UUID) ([]service.Obligation, error)
}

// TransparencyController serves a group's activity log and obligations.
// Every route is behind middleware.Auth.
type TransparencyController struct {
	transparency TransparencyService
}

func NewTransparencyController(transparency *service.TransparencyService) *TransparencyController {
	return &TransparencyController{transparency: transparency}
}

// Activity handles GET /groups/{group_id}/activity?cursor=&limit=.
func (h *TransparencyController) Activity(c fiber.Ctx) error {
	gid, err := groupID(c)
	if err != nil {
		return err
	}
	limit := service.DefaultActivityLimit
	if q := c.Query("limit"); q != "" {
		if limit, err = strconv.Atoi(q); err != nil {
			return model.ErrInvalidPagination.WithDetail("limit must be a number.")
		}
	}
	page, err := h.transparency.Activity(c.Context(), gid, middleware.UserID(c), c.Query("cursor"), limit)
	if err != nil {
		return err
	}
	meta := response.CursorMeta{NextCursor: page.NextCursor, HasMore: page.NextCursor != nil}
	return response.List(c, dto.NewActivityEntries(page.Entries), meta)
}

// Obligations handles GET /groups/{group_id}/obligations.
func (h *TransparencyController) Obligations(c fiber.Ctx) error {
	gid, err := groupID(c)
	if err != nil {
		return err
	}
	obligations, err := h.transparency.Obligations(c.Context(), gid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.List(c, dto.NewObligations(obligations), nil)
}
