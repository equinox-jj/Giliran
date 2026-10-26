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

// PaymentService is what PaymentController needs from service.PaymentService.
type PaymentService interface {
	Board(ctx context.Context, groupID, periodID, userID uuid.UUID) ([]service.PaymentView, repository.PaymentSummary, error)
	Get(ctx context.Context, groupID, paymentID, userID uuid.UUID) (service.PaymentDetail, error)
	UploadProof(ctx context.Context, groupID, paymentID, userID uuid.UUID, data []byte) (service.PaymentView, error)
	Approve(ctx context.Context, groupID, paymentID, userID uuid.UUID) (service.PaymentView, error)
	Reject(ctx context.Context, groupID, paymentID, userID uuid.UUID, reason string) (service.PaymentView, error)
	MarkPaid(ctx context.Context, groupID, paymentID, userID uuid.UUID, method model.PaymentMethod, note *string) (service.PaymentView, error)
}

// PaymentController serves the payment board and payment writes. Every route
// is behind middleware.Auth, and the writes behind Idempotency.
type PaymentController struct {
	payments PaymentService
}

func NewPaymentController(payments *service.PaymentService) *PaymentController {
	return &PaymentController{payments: payments}
}

// Board handles GET /groups/{group_id}/periods/{period_id}/payments.
func (h *PaymentController) Board(c fiber.Ctx) error {
	gid, err := groupID(c)
	if err != nil {
		return err
	}
	pid, err := periodID(c)
	if err != nil {
		return err
	}
	payments, sum, err := h.payments.Board(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.List(c, dto.NewPayments(payments), dto.PaymentBoardMeta{Summary: dto.NewPaymentSummary(sum)})
}

// Get handles GET /groups/{group_id}/payments/{payment_id}.
func (h *PaymentController) Get(c fiber.Ctx) error {
	gid, pid, err := paymentPath(c)
	if err != nil {
		return err
	}
	d, err := h.payments.Get(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPaymentDetail(d))
}

// UploadProof handles POST /groups/{group_id}/payments/{payment_id}/proofs
// (multipart field "file").
func (h *PaymentController) UploadProof(c fiber.Ctx) error {
	gid, pid, err := paymentPath(c)
	if err != nil {
		return err
	}
	data, err := readUpload(c)
	if err != nil {
		return err
	}
	v, err := h.payments.UploadProof(c.Context(), gid, pid, middleware.UserID(c), data)
	if err != nil {
		return err
	}
	return response.Created(c, "/api/v1/groups/"+gid.String()+"/payments/"+pid.String(), dto.NewPayment(v))
}

// Approve handles POST /groups/{group_id}/payments/{payment_id}/approve.
func (h *PaymentController) Approve(c fiber.Ctx) error {
	gid, pid, err := paymentPath(c)
	if err != nil {
		return err
	}
	v, err := h.payments.Approve(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPayment(v))
}

// Reject handles POST /groups/{group_id}/payments/{payment_id}/reject.
func (h *PaymentController) Reject(c fiber.Ctx) error {
	gid, pid, err := paymentPath(c)
	if err != nil {
		return err
	}
	var req dto.RejectPaymentRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	v, err := h.payments.Reject(c.Context(), gid, pid, middleware.UserID(c), req.Reason)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPayment(v))
}

// MarkPaid handles POST /groups/{group_id}/payments/{payment_id}/mark-paid.
func (h *PaymentController) MarkPaid(c fiber.Ctx) error {
	gid, pid, err := paymentPath(c)
	if err != nil {
		return err
	}
	var req dto.MarkPaidRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	v, err := h.payments.MarkPaid(c.Context(), gid, pid, middleware.UserID(c), model.PaymentMethod(req.Method), req.Note)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPayment(v))
}

// paymentPath parses the group_id and payment_id path parameters.
func paymentPath(c fiber.Ctx) (uuid.UUID, uuid.UUID, error) {
	gid, err := groupID(c)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	pid, err := paymentID(c)
	return gid, pid, err
}
