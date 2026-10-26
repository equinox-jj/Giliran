package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// DateLayout is how business dates (YYYY-MM-DD, Asia/Jakarta) appear in
// requests and responses.
const DateLayout = time.DateOnly

// CreateGroupRequest is the body of POST /groups. The service trims the name
// and checks its length again, and checks the start date is not in the past.
type CreateGroupRequest struct {
	Name               string `json:"name" validate:"required,min=3,max=60"`
	Amount             int64  `json:"amount" validate:"required,min=10000,max=100000000"`
	PeriodType         string `json:"period_type" validate:"required,oneof=weekly monthly"`
	TotalSlots         int16  `json:"total_slots" validate:"required,min=2,max=50"`
	StartDate          string `json:"start_date" validate:"required,datetime=2006-01-02"`
	DrawMethod         string `json:"draw_method" validate:"required,oneof=random fixed_order"`
	ReminderDaysBefore *int16 `json:"reminder_days_before" validate:"omitnil,min=0,max=7"`
}

// UpdateGroupRequest is the body of PATCH /groups/{group_id}. Absent fields
// keep their value; at least one must be present.
type UpdateGroupRequest struct {
	Name               *string `json:"name" validate:"omitnil,min=3,max=60"`
	ReminderDaysBefore *int16  `json:"reminder_days_before" validate:"omitnil,min=0,max=7"`
	Amount             *int64  `json:"amount" validate:"omitnil,min=10000,max=100000000"`
	PeriodType         *string `json:"period_type" validate:"omitnil,oneof=weekly monthly"`
	TotalSlots         *int16  `json:"total_slots" validate:"omitnil,min=2,max=50"`
	StartDate          *string `json:"start_date" validate:"omitnil,datetime=2006-01-02"`
	DrawMethod         *string `json:"draw_method" validate:"omitnil,oneof=random fixed_order"`
}

// Change converts the request; the validator has already checked the dates.
func (r UpdateGroupRequest) Change() (repository.GroupChange, bool) {
	c := repository.GroupChange{
		Name: r.Name, ReminderDaysBefore: r.ReminderDaysBefore, Amount: r.Amount, TotalSlots: r.TotalSlots,
	}
	if r.PeriodType != nil {
		v := model.PeriodType(*r.PeriodType)
		c.PeriodType = &v
	}
	if r.DrawMethod != nil {
		v := model.DrawMethod(*r.DrawMethod)
		c.DrawMethod = &v
	}
	if r.StartDate != nil {
		d, _ := time.Parse(DateLayout, *r.StartDate)
		c.StartDate = &d
	}
	empty := r.Name == nil && r.ReminderDaysBefore == nil && r.Amount == nil && r.PeriodType == nil &&
		r.TotalSlots == nil && r.StartDate == nil && r.DrawMethod == nil
	return c, !empty
}

// PaymentInfoRequest is the body of PUT /groups/{group_id}/payment-info.
type PaymentInfoRequest struct {
	BankName      string `json:"bank_name" validate:"required,max=50"`
	AccountNumber string `json:"account_number" validate:"required,number,min=6,max=20"`
	AccountHolder string `json:"account_holder" validate:"required,max=100"`
}

// FixedOrderRequest is the body of PUT /groups/{group_id}/fixed-order.
type FixedOrderRequest struct {
	Order []FixedOrderEntry `json:"order" validate:"required,min=2,max=50,dive"`
}

// FixedOrderEntry is one slot's payout position.
type FixedOrderEntry struct {
	SlotID   string `json:"slot_id" validate:"required,uuid"`
	Position int16  `json:"position" validate:"required,min=1"`
}

// Positions converts the request; the validator has already checked the IDs.
func (r FixedOrderRequest) Positions() []service.SlotPosition {
	out := make([]service.SlotPosition, len(r.Order))
	for i, e := range r.Order {
		out[i] = service.SlotPosition{SlotID: uuid.MustParse(e.SlotID), Position: e.Position}
	}
	return out
}

// UserSummary is the UserSummary schema: another user as members see them.
type UserSummary struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	AvatarURL *string   `json:"avatar_url"`
}

func NewUserSummary(u service.UserRef) UserSummary {
	return UserSummary{ID: u.ID, Name: u.Name, AvatarURL: u.AvatarURL}
}

// Invite is the Invite schema.
type Invite struct {
	InviteCode string `json:"invite_code"`
	InviteURL  string `json:"invite_url"`
}

func NewInvite(inv service.Invite) Invite {
	return Invite{InviteCode: inv.Code, InviteURL: inv.URL}
}

// PaymentInfo is the PaymentInfo schema.
type PaymentInfo struct {
	BankName         *string `json:"bank_name"`
	AccountNumber    *string `json:"account_number"`
	AccountHolder    *string `json:"account_holder"`
	QRISImageURL     *string `json:"qris_image_url"`
	QRISMerchantName *string `json:"qris_merchant_name"`
}

// Group is the Group schema.
type Group struct {
	ID                 uuid.UUID         `json:"id"`
	Name               string            `json:"name"`
	Amount             int64             `json:"amount"`
	PotAmount          int64             `json:"pot_amount"`
	PeriodType         model.PeriodType  `json:"period_type"`
	TotalSlots         int16             `json:"total_slots"`
	FilledSlots        int               `json:"filled_slots"`
	DrawMethod         model.DrawMethod  `json:"draw_method"`
	StartDate          string            `json:"start_date"`
	ReminderDaysBefore int16             `json:"reminder_days_before"`
	Status             model.GroupStatus `json:"status"`
	Organizer          UserSummary       `json:"organizer"`
	MyRole             model.MemberRole  `json:"my_role"`
	MyMemberID         uuid.UUID         `json:"my_member_id"`
	Invite             *Invite           `json:"invite"`
	PaymentInfo        PaymentInfo       `json:"payment_info"`
	CurrentPeriodID    *uuid.UUID        `json:"current_period_id"`
	StartedAt          *time.Time        `json:"started_at"`
	CompletedAt        *time.Time        `json:"completed_at"`
	ClosedAt           *time.Time        `json:"closed_at"`
	CreatedAt          time.Time         `json:"created_at"`
	UpdatedAt          time.Time         `json:"updated_at"`
}

func NewGroup(d service.GroupDetail) Group {
	g := d.Group
	out := Group{
		ID:                 g.ID,
		Name:               g.Name,
		Amount:             g.Amount,
		PotAmount:          g.TotalPot(),
		PeriodType:         g.PeriodType,
		TotalSlots:         g.TotalSlots,
		FilledSlots:        d.FilledSlots,
		DrawMethod:         g.DrawMethod,
		StartDate:          g.StartDate.Format(DateLayout),
		ReminderDaysBefore: g.ReminderDaysBefore,
		Status:             g.Status,
		Organizer:          NewUserSummary(d.Organizer),
		MyRole:             d.Me.Role,
		MyMemberID:         d.Me.ID,
		PaymentInfo: PaymentInfo{
			BankName:         g.BankName,
			AccountNumber:    g.BankAccountNumber,
			AccountHolder:    g.BankAccountHolder,
			QRISImageURL:     d.QRISImageURL,
			QRISMerchantName: d.QRISMerchantName,
		},
		CurrentPeriodID: d.CurrentPeriodID,
		StartedAt:       g.StartedAt,
		CompletedAt:     g.CompletedAt,
		ClosedAt:        g.ClosedAt,
		CreatedAt:       g.CreatedAt,
		UpdatedAt:       g.UpdatedAt,
	}
	if d.Invite != nil {
		inv := NewInvite(*d.Invite)
		out.Invite = &inv
	}
	return out
}

// GroupSummary is the GroupSummary schema: a card on the home screen.
type GroupSummary struct {
	ID                 uuid.UUID            `json:"id"`
	Name               string               `json:"name"`
	Amount             int64                `json:"amount"`
	PeriodType         model.PeriodType     `json:"period_type"`
	Status             model.GroupStatus    `json:"status"`
	MyRole             model.MemberRole     `json:"my_role"`
	TotalSlots         int16                `json:"total_slots"`
	FilledSlots        int                  `json:"filled_slots"`
	CurrentPeriodNo    *int16               `json:"current_period_no"`
	NextDueDate        *string              `json:"next_due_date"`
	NextDrawDate       *string              `json:"next_draw_date"`
	MyPaymentStatus    *model.PaymentStatus `json:"my_payment_status"`
	PaidCount          *int                 `json:"paid_count"`
	PendingReviewCount *int                 `json:"pending_review_count"`
	IHaveWon           bool                 `json:"i_have_won"`
}

// NewGroupSummaries maps the home screen groups. Counts are null while no
// period is open, and the review count is for organizers only.
func NewGroupSummaries(groups []repository.GroupSummary) []GroupSummary {
	out := make([]GroupSummary, len(groups))
	for i, g := range groups {
		s := GroupSummary{
			ID:              g.ID,
			Name:            g.Name,
			Amount:          g.Amount,
			PeriodType:      g.PeriodType,
			Status:          g.Status,
			MyRole:          g.MyRole,
			TotalSlots:      g.TotalSlots,
			FilledSlots:     g.FilledSlots,
			CurrentPeriodNo: g.CurrentPeriodNo,
			NextDueDate:     formatDate(g.NextDueDate),
			NextDrawDate:    formatDate(g.NextDrawDate),
			MyPaymentStatus: g.MyPaymentStatus,
			IHaveWon:        g.IHaveWon,
		}
		if g.CurrentPeriodID != nil {
			s.PaidCount = &g.PaidCount
			if g.MyRole.CanManageGroup() {
				s.PendingReviewCount = &g.PendingReviewCount
			}
		}
		out[i] = s
	}
	return out
}

func formatDate(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format(DateLayout)
	return &s
}
