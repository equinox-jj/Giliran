package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// GuestRequest is the body of POST /groups/{group_id}/guests. The service
// trims the name and normalizes the phone.
type GuestRequest struct {
	Name  string  `json:"name" validate:"required,min=2,max=50"`
	Phone *string `json:"phone"`
}

// UpdateGuestRequest is the body of PATCH /groups/{group_id}/members/{member_id}.
// A null phone removes it; at least one field must be present.
type UpdateGuestRequest struct {
	Name  *string          `json:"name" validate:"omitnil,min=2,max=50"`
	Phone Optional[string] `json:"phone"`
}

// Change converts the request and reports whether it changes anything.
func (r UpdateGuestRequest) Change() (service.GuestChange, bool) {
	return service.GuestChange{Name: r.Name, SetPhone: r.Phone.Set, Phone: r.Phone.Value}, r.Name != nil || r.Phone.Set
}

// ReasonRequest is the optional body of POST .../leave-requests and of
// rejecting one.
type ReasonRequest struct {
	Reason *string `json:"reason" validate:"omitnil,max=500"`
}

// OwnershipTransferRequest is the body of POST /groups/{group_id}/ownership-transfers.
type OwnershipTransferRequest struct {
	ToMemberID string `json:"to_member_id" validate:"required,uuid"`
}

// Member is the Member schema.
type Member struct {
	ID                 uuid.UUID          `json:"id"`
	User               *UserSummary       `json:"user"`
	DisplayName        string             `json:"display_name"`
	IsGuest            bool               `json:"is_guest"`
	GuestPhone         *string            `json:"guest_phone"`
	Role               model.MemberRole   `json:"role"`
	Status             model.MemberStatus `json:"status"`
	SlotID             uuid.UUID          `json:"slot_id"`
	SlotNo             int16              `json:"slot_no"`
	FixedOrderPosition *int16             `json:"fixed_order_position"`
	HasWon             bool               `json:"has_won"`
	WonPeriodNo        *int16             `json:"won_period_no"`
	JoinedAt           time.Time          `json:"joined_at"`
}

func NewMember(m service.Member) Member {
	out := Member{
		ID:                 m.Member.ID,
		DisplayName:        m.DisplayName(),
		IsGuest:            m.Member.IsGuest(),
		GuestPhone:         m.Member.GuestPhone,
		Role:               m.Member.Role,
		Status:             m.Member.Status,
		SlotID:             m.SlotID,
		SlotNo:             m.SlotNo,
		FixedOrderPosition: m.FixedOrderPosition,
		HasWon:             m.WonPeriodNo != nil,
		WonPeriodNo:        m.WonPeriodNo,
		JoinedAt:           m.Member.JoinedAt,
	}
	if m.Member.UserID != nil {
		out.User = &UserSummary{ID: *m.Member.UserID, Name: m.DisplayName(), AvatarURL: m.AvatarURL}
	}
	return out
}

func NewMembers(members []service.Member) []Member {
	out := make([]Member, len(members))
	for i, m := range members {
		out[i] = NewMember(m)
	}
	return out
}

// MemberRef is the MemberRef schema: a compact member inside other resources.
type MemberRef struct {
	ID          uuid.UUID `json:"id"`
	DisplayName string    `json:"display_name"`
	AvatarURL   *string   `json:"avatar_url"`
	IsGuest     bool      `json:"is_guest"`
	SlotNo      int16     `json:"slot_no"`
}

func NewMemberRef(m service.Member) MemberRef {
	return MemberRef{ID: m.Member.ID, DisplayName: m.DisplayName(), AvatarURL: m.AvatarURL, IsGuest: m.Member.IsGuest(), SlotNo: m.SlotNo}
}

// InvitePreview is the InvitePreview schema.
type InvitePreview struct {
	GroupID       uuid.UUID         `json:"group_id"`
	GroupName     string            `json:"group_name"`
	Organizer     UserSummary       `json:"organizer"`
	Amount        int64             `json:"amount"`
	PeriodType    model.PeriodType  `json:"period_type"`
	TotalSlots    int16             `json:"total_slots"`
	FilledSlots   int               `json:"filled_slots"`
	StartDate     string            `json:"start_date"`
	Status        model.GroupStatus `json:"status"`
	CanJoin       bool              `json:"can_join"`
	AlreadyMember bool              `json:"already_member"`
}

func NewInvitePreview(p service.InvitePreview) InvitePreview {
	return InvitePreview{
		GroupID:       p.Group.ID,
		GroupName:     p.Group.Name,
		Organizer:     NewUserSummary(p.Organizer),
		Amount:        p.Group.Amount,
		PeriodType:    p.Group.PeriodType,
		TotalSlots:    p.Group.TotalSlots,
		FilledSlots:   p.FilledSlots,
		StartDate:     p.Group.StartDate.Format(DateLayout),
		Status:        p.Group.Status,
		CanJoin:       p.CanJoin,
		AlreadyMember: p.AlreadyMember,
	}
}

// ClaimLink is the ClaimLink schema.
type ClaimLink struct {
	ClaimURL  string    `json:"claim_url"`
	ExpiresAt time.Time `json:"expires_at"`
}

// LeaveRequest is the LeaveRequest schema.
type LeaveRequest struct {
	ID         uuid.UUID                `json:"id"`
	Member     MemberRef                `json:"member"`
	Reason     *string                  `json:"reason"`
	Status     model.LeaveRequestStatus `json:"status"`
	ReviewedBy *UserSummary             `json:"reviewed_by"`
	ReviewedAt *time.Time               `json:"reviewed_at"`
	CreatedAt  time.Time                `json:"created_at"`
}

func NewLeaveRequest(r service.LeaveRequest) LeaveRequest {
	out := LeaveRequest{
		ID:         r.Request.ID,
		Member:     NewMemberRef(r.Member),
		Reason:     r.Request.Reason,
		Status:     r.Request.Status,
		ReviewedAt: r.Request.ReviewedAt,
		CreatedAt:  r.Request.CreatedAt,
	}
	if r.ReviewedBy != nil {
		u := NewUserSummary(*r.ReviewedBy)
		out.ReviewedBy = &u
	}
	return out
}

func NewLeaveRequests(reqs []service.LeaveRequest) []LeaveRequest {
	out := make([]LeaveRequest, len(reqs))
	for i, r := range reqs {
		out[i] = NewLeaveRequest(r)
	}
	return out
}

// OwnershipTransfer is the OwnershipTransfer schema.
type OwnershipTransfer struct {
	ID          uuid.UUID                     `json:"id"`
	FromUser    UserSummary                   `json:"from_user"`
	ToMember    MemberRef                     `json:"to_member"`
	Status      model.OwnershipTransferStatus `json:"status"`
	ExpiresAt   time.Time                     `json:"expires_at"`
	RespondedAt *time.Time                    `json:"responded_at"`
	CreatedAt   time.Time                     `json:"created_at"`
}

func NewOwnershipTransfer(t service.OwnershipTransfer) OwnershipTransfer {
	return OwnershipTransfer{
		ID:          t.Transfer.ID,
		FromUser:    NewUserSummary(t.From),
		ToMember:    NewMemberRef(t.To),
		Status:      t.Transfer.Status,
		ExpiresAt:   t.Transfer.ExpiresAt,
		RespondedAt: t.Transfer.RespondedAt,
		CreatedAt:   t.Transfer.CreatedAt,
	}
}
