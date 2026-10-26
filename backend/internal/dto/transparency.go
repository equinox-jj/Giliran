package dto

import (
	"encoding/json"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
)

// ActivityEntry is the ActivityEntry schema. The id is a string so
// JavaScript clients never round it.
type ActivityEntry struct {
	ID         string           `json:"id"`
	Action     model.Action     `json:"action"`
	EntityType model.EntityType `json:"entity_type"`
	EntityID   *uuid.UUID       `json:"entity_id"`
	Actor      *UserSummary     `json:"actor"`
	Subject    *MemberRef       `json:"subject"`
	Before     json.RawMessage  `json:"before"`
	After      json.RawMessage  `json:"after"`
	CreatedAt  time.Time        `json:"created_at"`
}

func NewActivityEntries(es []service.ActivityEntry) []ActivityEntry {
	out := make([]ActivityEntry, len(es))
	for i, e := range es {
		out[i] = ActivityEntry{
			ID:         strconv.FormatInt(e.Log.ID, 10),
			Action:     e.Log.Action,
			EntityType: e.Log.EntityType,
			EntityID:   e.Log.EntityID,
			Before:     e.Log.Before,
			After:      e.Log.After,
			CreatedAt:  e.Log.CreatedAt,
		}
		if e.Actor != nil {
			a := NewUserSummary(*e.Actor)
			out[i].Actor = &a
		}
		if e.Subject != nil {
			s := NewMemberRef(*e.Subject)
			out[i].Subject = &s
		}
	}
	return out
}

// Obligation is the Obligation schema.
type Obligation struct {
	Member          MemberRef `json:"member"`
	WonPeriodNo     int16     `json:"won_period_no"`
	RemainingCount  int       `json:"remaining_count"`
	RemainingAmount int64     `json:"remaining_amount"`
	OverdueCount    int       `json:"overdue_count"`
	OverdueAmount   int64     `json:"overdue_amount"`
}

func NewObligations(os []service.Obligation) []Obligation {
	out := make([]Obligation, len(os))
	for i, o := range os {
		out[i] = Obligation{
			Member:          NewMemberRef(o.Member),
			WonPeriodNo:     o.WonPeriodNo,
			RemainingCount:  o.RemainingCount,
			RemainingAmount: o.RemainingAmount,
			OverdueCount:    o.OverdueCount,
			OverdueAmount:   o.OverdueAmount,
		}
	}
	return out
}

// SendRemindersRequest is the optional body of POST .../reminders; no
// member_ids reminds every unpaid member.
type SendRemindersRequest struct {
	MemberIDs []string `json:"member_ids" validate:"omitempty,max=100,dive,uuid"`
}

// IDs parses the member IDs, which the validator has already checked.
func (r SendRemindersRequest) IDs() []uuid.UUID {
	out := make([]uuid.UUID, len(r.MemberIDs))
	for i, id := range r.MemberIDs {
		out[i] = uuid.MustParse(id)
	}
	return out
}

// ReminderSkip is an entry of ReminderResult.skipped.
type ReminderSkip struct {
	Member        MemberRef                  `json:"member"`
	Reason        service.ReminderSkipReason `json:"reason"`
	WhatsAppPhone *string                    `json:"whatsapp_phone"`
}

// ReminderResult is the ReminderResult schema.
type ReminderResult struct {
	SentCount int            `json:"sent_count"`
	Skipped   []ReminderSkip `json:"skipped"`
}

func NewReminderResult(r service.ReminderResult) ReminderResult {
	out := ReminderResult{SentCount: r.SentCount, Skipped: make([]ReminderSkip, len(r.Skipped))}
	for i, s := range r.Skipped {
		out.Skipped[i] = ReminderSkip{Member: NewMemberRef(s.Member), Reason: s.Reason, WhatsAppPhone: s.WhatsAppPhone}
	}
	return out
}

// RecapUnpaid is an entry of Recap.unpaid.
type RecapUnpaid struct {
	Member        MemberRef `json:"member"`
	WhatsAppPhone *string   `json:"whatsapp_phone"`
}

// Recap is the Recap schema.
type Recap struct {
	GroupName       string        `json:"group_name"`
	PeriodNo        int16         `json:"period_no"`
	TotalPeriods    int16         `json:"total_periods"`
	DueDate         string        `json:"due_date"`
	DrawDate        string        `json:"draw_date"`
	Amount          int64         `json:"amount"`
	PaidCount       int           `json:"paid_count"`
	TotalCount      int           `json:"total_count"`
	CollectedAmount int64         `json:"collected_amount"`
	ExpectedAmount  int64         `json:"expected_amount"`
	Unpaid          []RecapUnpaid `json:"unpaid"`
	LastWinner      *MemberRef    `json:"last_winner"`
	PaymentInfo     PaymentInfo   `json:"payment_info"`
}

func NewRecap(r service.Recap) Recap {
	out := Recap{
		GroupName:       r.Group.Name,
		PeriodNo:        r.Period.PeriodNo,
		TotalPeriods:    r.Group.TotalSlots,
		DueDate:         r.Period.DueDate.Format(DateLayout),
		DrawDate:        r.Period.DrawDate.Format(DateLayout),
		Amount:          r.Group.Amount,
		PaidCount:       r.Summary.PaidCount,
		TotalCount:      r.Summary.TotalCount,
		CollectedAmount: r.Summary.CollectedAmount,
		ExpectedAmount:  r.Summary.ExpectedAmount,
		Unpaid:          make([]RecapUnpaid, len(r.Unpaid)),
		PaymentInfo: PaymentInfo{
			BankName:         r.Group.BankName,
			AccountNumber:    r.Group.BankAccountNumber,
			AccountHolder:    r.Group.BankAccountHolder,
			QRISImageURL:     r.QRISImageURL,
			QRISMerchantName: r.QRISMerchantName,
		},
	}
	for i, u := range r.Unpaid {
		out.Unpaid[i] = RecapUnpaid{Member: NewMemberRef(u.Member), WhatsAppPhone: u.WhatsAppPhone}
	}
	if r.LastWinner != nil {
		w := NewMemberRef(*r.LastWinner)
		out.LastWinner = &w
	}
	return out
}
