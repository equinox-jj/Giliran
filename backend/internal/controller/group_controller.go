package controller

import (
	"context"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// GroupService is what GroupController needs from service.GroupService.
type GroupService interface {
	Create(ctx context.Context, userID uuid.UUID, ng service.NewGroup) (service.GroupDetail, error)
	Get(ctx context.Context, groupID, userID uuid.UUID) (service.GroupDetail, error)
	ListMine(ctx context.Context, userID uuid.UUID, filter service.MyGroupsFilter) ([]repository.GroupSummary, error)
	Update(ctx context.Context, groupID, userID uuid.UUID, c repository.GroupChange) (service.GroupDetail, error)
	SetPaymentInfo(ctx context.Context, groupID, userID uuid.UUID, bank, number, holder string) (service.GroupDetail, error)
	UploadQRIS(ctx context.Context, groupID, userID uuid.UUID, data []byte) (service.GroupDetail, error)
	DeleteQRIS(ctx context.Context, groupID, userID uuid.UUID) error
	SetFixedOrder(ctx context.Context, groupID, userID uuid.UUID, order []service.SlotPosition) ([]service.Member, error)
	Close(ctx context.Context, groupID, userID uuid.UUID) (service.GroupDetail, error)
	ResetInvite(ctx context.Context, groupID, userID uuid.UUID) (service.Invite, error)
}

// GroupController serves /me/groups and /groups/{group_id} with its payment
// info, fixed order, close and invite reset. Every route is behind
// middleware.Auth.
type GroupController struct {
	groups GroupService
}

func NewGroupController(groups *service.GroupService) *GroupController {
	return &GroupController{groups: groups}
}

// ListMine handles GET /me/groups.
func (h *GroupController) ListMine(c fiber.Ctx) error {
	filter := service.MyGroupsFilter(c.Query("status", string(service.MyGroupsActive)))
	switch filter {
	case service.MyGroupsActive, service.MyGroupsFinished, service.MyGroupsAll:
	default:
		return model.NewValidationError(model.FieldError{
			Field: "status", Code: model.FieldInvalidChoice, Message: "Must be one of: active, finished, all.",
		})
	}
	groups, err := h.groups.ListMine(c.Context(), middleware.UserID(c), filter)
	if err != nil {
		return err
	}
	return response.List(c, dto.NewGroupSummaries(groups), nil)
}

// Create handles POST /groups.
func (h *GroupController) Create(c fiber.Ctx) error {
	var req dto.CreateGroupRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	start, _ := time.Parse(dto.DateLayout, req.StartDate)
	reminder := int16(model.DefaultReminderDaysBefore)
	if req.ReminderDaysBefore != nil {
		reminder = *req.ReminderDaysBefore
	}
	d, err := h.groups.Create(c.Context(), middleware.UserID(c), service.NewGroup{
		Name:               req.Name,
		Amount:             req.Amount,
		PeriodType:         model.PeriodType(req.PeriodType),
		TotalSlots:         req.TotalSlots,
		DrawMethod:         model.DrawMethod(req.DrawMethod),
		StartDate:          start,
		ReminderDaysBefore: reminder,
	})
	if err != nil {
		return err
	}
	return response.Created(c, "/api/v1/groups/"+d.Group.ID.String(), dto.NewGroup(d))
}

// Get handles GET /groups/{group_id}.
func (h *GroupController) Get(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	d, err := h.groups.Get(c.Context(), id, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewGroup(d))
}

// Update handles PATCH /groups/{group_id}.
func (h *GroupController) Update(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var req dto.UpdateGroupRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	change, ok := req.Change()
	if !ok {
		return model.ErrValidation.WithDetail("Send at least one setting to change.")
	}
	d, err := h.groups.Update(c.Context(), id, middleware.UserID(c), change)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewGroup(d))
}

// SetPaymentInfo handles PUT /groups/{group_id}/payment-info.
func (h *GroupController) SetPaymentInfo(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var req dto.PaymentInfoRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	d, err := h.groups.SetPaymentInfo(c.Context(), id, middleware.UserID(c), req.BankName, req.AccountNumber, req.AccountHolder)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewGroup(d))
}

// UploadQRIS handles PUT /groups/{group_id}/payment-info/qris (multipart
// field "file").
func (h *GroupController) UploadQRIS(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	data, err := readUpload(c)
	if err != nil {
		return err
	}
	d, err := h.groups.UploadQRIS(c.Context(), id, middleware.UserID(c), data)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewGroup(d))
}

// DeleteQRIS handles DELETE /groups/{group_id}/payment-info/qris.
func (h *GroupController) DeleteQRIS(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	if err := h.groups.DeleteQRIS(c.Context(), id, middleware.UserID(c)); err != nil {
		return err
	}
	return response.NoContent(c)
}

// SetFixedOrder handles PUT /groups/{group_id}/fixed-order.
func (h *GroupController) SetFixedOrder(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var req dto.FixedOrderRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	members, err := h.groups.SetFixedOrder(c.Context(), id, middleware.UserID(c), req.Positions())
	if err != nil {
		return err
	}
	return response.List(c, dto.NewMembers(members), nil)
}

// Close handles POST /groups/{group_id}/close.
func (h *GroupController) Close(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	d, err := h.groups.Close(c.Context(), id, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewGroup(d))
}

// ResetInvite handles POST /groups/{group_id}/invite-code/reset.
func (h *GroupController) ResetInvite(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	inv, err := h.groups.ResetInvite(c.Context(), id, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewInvite(inv))
}
