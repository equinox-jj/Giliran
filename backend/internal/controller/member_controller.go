package controller

import (
	"context"
	"fmt"
	"regexp"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// inviteCodePattern is the InviteCode parameter, case-insensitive: codes are
// stored upper case.
var inviteCodePattern = regexp.MustCompile(`^[A-Za-z0-9]{8}$`)

// claimTokenPattern is the claim_token parameter: URL-safe base64.
var claimTokenPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{32,64}$`)

// MemberService is what MemberController needs from service.MemberService.
type MemberService interface {
	PreviewInvite(ctx context.Context, userID uuid.UUID, code string) (service.InvitePreview, error)
	Join(ctx context.Context, userID uuid.UUID, code string) (service.Member, error)
	List(ctx context.Context, groupID, userID uuid.UUID, includeInactive bool) ([]service.Member, error)
	Get(ctx context.Context, groupID, userID, memberID uuid.UUID) (service.Member, error)
	AddGuest(ctx context.Context, groupID, userID uuid.UUID, name string, phone *string) (service.Member, error)
	UpdateGuest(ctx context.Context, groupID, userID, memberID uuid.UUID, c service.GuestChange) (service.Member, error)
	Remove(ctx context.Context, groupID, userID, memberID uuid.UUID) error
	CreateClaimLink(ctx context.Context, groupID, userID, memberID uuid.UUID) (service.ClaimLink, error)
	Claim(ctx context.Context, userID uuid.UUID, token string) (service.Member, error)
}

// LeaveService is what MemberController needs from service.LeaveService.
type LeaveService interface {
	List(ctx context.Context, groupID, userID uuid.UUID, status *model.LeaveRequestStatus) ([]service.LeaveRequest, error)
	Request(ctx context.Context, groupID, userID uuid.UUID, reason *string) (service.LeaveRequest, error)
	Approve(ctx context.Context, groupID, userID, requestID uuid.UUID) (service.LeaveRequest, error)
	Reject(ctx context.Context, groupID, userID, requestID uuid.UUID, reason *string) (service.LeaveRequest, error)
}

// OwnershipService is what MemberController needs from
// service.OwnershipService.
type OwnershipService interface {
	Offer(ctx context.Context, groupID, userID, toMemberID uuid.UUID) (service.OwnershipTransfer, error)
	Accept(ctx context.Context, groupID, userID, transferID uuid.UUID) (service.OwnershipTransfer, error)
	Decline(ctx context.Context, groupID, userID, transferID uuid.UUID) (service.OwnershipTransfer, error)
}

// MemberController serves invites, members, guests, claims, leave requests
// and ownership transfers. Every route is behind middleware.Auth.
type MemberController struct {
	members   MemberService
	leaves    LeaveService
	ownership OwnershipService
}

func NewMemberController(members *service.MemberService, leaves *service.LeaveService, ownership *service.OwnershipService) *MemberController {
	return &MemberController{members: members, leaves: leaves, ownership: ownership}
}

func inviteCode(c fiber.Ctx) (string, error) {
	code := c.Params("invite_code")
	if !inviteCodePattern.MatchString(code) {
		return "", model.ErrInviteNotFound
	}
	return code, nil
}

func memberLocation(m service.Member) string {
	return fmt.Sprintf("/api/v1/groups/%s/members/%s", m.Member.GroupID, m.Member.ID)
}

// PreviewInvite handles GET /invites/{invite_code}.
func (h *MemberController) PreviewInvite(c fiber.Ctx) error {
	code, err := inviteCode(c)
	if err != nil {
		return err
	}
	p, err := h.members.PreviewInvite(c.Context(), middleware.UserID(c), code)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewInvitePreview(p))
}

// Join handles POST /invites/{invite_code}/join.
func (h *MemberController) Join(c fiber.Ctx) error {
	code, err := inviteCode(c)
	if err != nil {
		return err
	}
	m, err := h.members.Join(c.Context(), middleware.UserID(c), code)
	if err != nil {
		return err
	}
	return response.Created(c, memberLocation(m), dto.NewMember(m))
}

// List handles GET /groups/{group_id}/members.
func (h *MemberController) List(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var all bool
	switch c.Query("status", "active") {
	case "active":
	case "all":
		all = true
	default:
		return model.NewValidationError(model.FieldError{
			Field: "status", Code: model.FieldInvalidChoice, Message: "Must be one of: active, all.",
		})
	}
	members, err := h.members.List(c.Context(), id, middleware.UserID(c), all)
	if err != nil {
		return err
	}
	return response.List(c, dto.NewMembers(members), nil)
}

// groupAndMember parses group_id and member_id.
func groupAndMember(c fiber.Ctx) (uuid.UUID, uuid.UUID, error) {
	gid, err := groupID(c)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	mid, err := pathID(c, "member_id", model.ErrMemberNotFound)
	return gid, mid, err
}

// Get handles GET /groups/{group_id}/members/{member_id}.
func (h *MemberController) Get(c fiber.Ctx) error {
	gid, mid, err := groupAndMember(c)
	if err != nil {
		return err
	}
	m, err := h.members.Get(c.Context(), gid, middleware.UserID(c), mid)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMember(m))
}

// AddGuest handles POST /groups/{group_id}/guests.
func (h *MemberController) AddGuest(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var req dto.GuestRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	m, err := h.members.AddGuest(c.Context(), id, middleware.UserID(c), req.Name, req.Phone)
	if err != nil {
		return err
	}
	return response.Created(c, memberLocation(m), dto.NewMember(m))
}

// UpdateGuest handles PATCH /groups/{group_id}/members/{member_id}.
func (h *MemberController) UpdateGuest(c fiber.Ctx) error {
	gid, mid, err := groupAndMember(c)
	if err != nil {
		return err
	}
	var req dto.UpdateGuestRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	change, ok := req.Change()
	if !ok {
		return model.ErrValidation.WithDetail("Send a name or phone to change.")
	}
	m, err := h.members.UpdateGuest(c.Context(), gid, middleware.UserID(c), mid, change)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMember(m))
}

// Remove handles DELETE /groups/{group_id}/members/{member_id}.
func (h *MemberController) Remove(c fiber.Ctx) error {
	gid, mid, err := groupAndMember(c)
	if err != nil {
		return err
	}
	if err := h.members.Remove(c.Context(), gid, middleware.UserID(c), mid); err != nil {
		return err
	}
	return response.NoContent(c)
}

// CreateClaimLink handles POST /groups/{group_id}/members/{member_id}/claim-link.
func (h *MemberController) CreateClaimLink(c fiber.Ctx) error {
	gid, mid, err := groupAndMember(c)
	if err != nil {
		return err
	}
	link, err := h.members.CreateClaimLink(c.Context(), gid, middleware.UserID(c), mid)
	if err != nil {
		return err
	}
	return response.Created(c, "", dto.ClaimLink{ClaimURL: link.URL, ExpiresAt: link.ExpiresAt})
}

// Claim handles POST /claims/{claim_token}.
func (h *MemberController) Claim(c fiber.Ctx) error {
	token := c.Params("claim_token")
	if !claimTokenPattern.MatchString(token) {
		return model.ErrClaimNotFound
	}
	m, err := h.members.Claim(c.Context(), middleware.UserID(c), token)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewMember(m))
}

// ListLeaveRequests handles GET /groups/{group_id}/leave-requests.
func (h *MemberController) ListLeaveRequests(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var status *model.LeaveRequestStatus
	if q := c.Query("status"); q != "" {
		s := model.LeaveRequestStatus(q)
		if !s.IsValid() {
			return model.NewValidationError(model.FieldError{
				Field: "status", Code: model.FieldInvalidChoice, Message: "Must be one of: pending, approved, rejected, cancelled.",
			})
		}
		status = &s
	}
	reqs, err := h.leaves.List(c.Context(), id, middleware.UserID(c), status)
	if err != nil {
		return err
	}
	return response.List(c, dto.NewLeaveRequests(reqs), nil)
}

// RequestLeave handles POST /groups/{group_id}/leave-requests.
func (h *MemberController) RequestLeave(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var req dto.ReasonRequest
	if err := bindOptional(c, &req); err != nil {
		return err
	}
	lr, err := h.leaves.Request(c.Context(), id, middleware.UserID(c), req.Reason)
	if err != nil {
		return err
	}
	return response.Created(c, "", dto.NewLeaveRequest(lr))
}

// groupAndRequest parses group_id and request_id.
func groupAndRequest(c fiber.Ctx) (uuid.UUID, uuid.UUID, error) {
	gid, err := groupID(c)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	rid, err := pathID(c, "request_id", model.ErrNotFound.WithDetail("Leave request not found."))
	return gid, rid, err
}

// ApproveLeave handles POST /groups/{group_id}/leave-requests/{request_id}/approve.
func (h *MemberController) ApproveLeave(c fiber.Ctx) error {
	gid, rid, err := groupAndRequest(c)
	if err != nil {
		return err
	}
	lr, err := h.leaves.Approve(c.Context(), gid, middleware.UserID(c), rid)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewLeaveRequest(lr))
}

// RejectLeave handles POST /groups/{group_id}/leave-requests/{request_id}/reject.
func (h *MemberController) RejectLeave(c fiber.Ctx) error {
	gid, rid, err := groupAndRequest(c)
	if err != nil {
		return err
	}
	var req dto.ReasonRequest
	if err := bindOptional(c, &req); err != nil {
		return err
	}
	lr, err := h.leaves.Reject(c.Context(), gid, middleware.UserID(c), rid, req.Reason)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewLeaveRequest(lr))
}

// OfferOwnership handles POST /groups/{group_id}/ownership-transfers.
func (h *MemberController) OfferOwnership(c fiber.Ctx) error {
	id, err := groupID(c)
	if err != nil {
		return err
	}
	var req dto.OwnershipTransferRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	t, err := h.ownership.Offer(c.Context(), id, middleware.UserID(c), uuid.MustParse(req.ToMemberID))
	if err != nil {
		return err
	}
	return response.Created(c, "", dto.NewOwnershipTransfer(t))
}

// groupAndTransfer parses group_id and transfer_id.
func groupAndTransfer(c fiber.Ctx) (uuid.UUID, uuid.UUID, error) {
	gid, err := groupID(c)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	tid, err := pathID(c, "transfer_id", model.ErrNotFound.WithDetail("Ownership transfer not found."))
	return gid, tid, err
}

// AcceptOwnership handles POST /groups/{group_id}/ownership-transfers/{transfer_id}/accept.
func (h *MemberController) AcceptOwnership(c fiber.Ctx) error {
	gid, tid, err := groupAndTransfer(c)
	if err != nil {
		return err
	}
	t, err := h.ownership.Accept(c.Context(), gid, middleware.UserID(c), tid)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewOwnershipTransfer(t))
}

// DeclineOwnership handles POST /groups/{group_id}/ownership-transfers/{transfer_id}/decline.
func (h *MemberController) DeclineOwnership(c fiber.Ctx) error {
	gid, tid, err := groupAndTransfer(c)
	if err != nil {
		return err
	}
	t, err := h.ownership.Decline(c.Context(), gid, middleware.UserID(c), tid)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewOwnershipTransfer(t))
}
