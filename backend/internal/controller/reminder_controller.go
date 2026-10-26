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

// ReminderService is what ReminderController needs from
// service.ReminderService.
type ReminderService interface {
	Send(ctx context.Context, groupID, periodID, userID uuid.UUID, memberIDs []uuid.UUID) (service.ReminderResult, error)
	Recap(ctx context.Context, groupID, periodID, userID uuid.UUID) (service.Recap, error)
}

// ReminderController serves a period's reminders and recap. Every route is
// behind middleware.Auth, and sending behind Idempotency.
type ReminderController struct {
	reminders ReminderService
}

func NewReminderController(reminders *service.ReminderService) *ReminderController {
	return &ReminderController{reminders: reminders}
}

// Send handles POST /groups/{group_id}/periods/{period_id}/reminders.
func (h *ReminderController) Send(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	var req dto.SendRemindersRequest
	if err := bindOptional(c, &req); err != nil {
		return err
	}
	res, err := h.reminders.Send(c.Context(), gid, pid, middleware.UserID(c), req.IDs())
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewReminderResult(res))
}

// Recap handles GET /groups/{group_id}/periods/{period_id}/recap.
func (h *ReminderController) Recap(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	r, err := h.reminders.Recap(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewRecap(r))
}
