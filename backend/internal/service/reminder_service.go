package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// ReminderCooldown is how long a member's payment in one period is spared
// another manual push reminder.
const ReminderCooldown = 6 * time.Hour

// ReminderSkipReason is why a member got no push reminder (ReminderResult).
type ReminderSkipReason string

const (
	ReminderSkipGuest            ReminderSkipReason = "guest"
	ReminderSkipNoDevice         ReminderSkipReason = "no_device"
	ReminderSkipNotificationsOff ReminderSkipReason = "notifications_off"
	ReminderSkipRecentlyReminded ReminderSkipReason = "recently_reminded"
	ReminderSkipAlreadyPaid      ReminderSkipReason = "already_paid"
)

// ReminderSkip is a member left out of a push reminder. WhatsAppPhone is
// their number, when there is one, so the organizer can message them
// instead.
type ReminderSkip struct {
	Member        Member
	Reason        ReminderSkipReason
	WhatsAppPhone *string
}

// ReminderResult is what sending reminders did.
type ReminderResult struct {
	SentCount int
	Skipped   []ReminderSkip
}

// RecapUnpaid is a member who has not paid the period. WhatsAppPhone is set
// only for organizers and co-organizers.
type RecapUnpaid struct {
	Member        Member
	WhatsAppPhone *string
}

// Recap is the data behind the WhatsApp recap image and reminder messages
// (FR-REM-02, FR-REM-03). The app renders both.
type Recap struct {
	Group            model.Group
	Period           model.Period
	Summary          repository.PaymentSummary
	Unpaid           []RecapUnpaid
	LastWinner       *Member
	QRISImageURL     *string
	QRISMerchantName *string
}

// ReminderService sends push reminders on request and builds the period
// recap (features 31–33).
type ReminderService struct {
	tx       *repository.TxManager
	groups   *repository.GroupRepository
	periods  *repository.PeriodRepository
	payments *repository.PaymentRepository
	members  *repository.MemberRepository
	authz    *Authz
	activity *Activity
	refs     refs
	clock    clock.Clock
}

func NewReminderService(
	tx *repository.TxManager,
	groups *repository.GroupRepository,
	periods *repository.PeriodRepository,
	payments *repository.PaymentRepository,
	members *repository.MemberRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
) *ReminderService {
	return &ReminderService{
		tx: tx, groups: groups, periods: periods, payments: payments, members: members, authz: authz, activity: activity,
		refs: refs{users: users, store: store}, clock: clk,
	}
}

// Send pushes a payment reminder to the period's unpaid members, or only to
// memberIDs when given. Organizers and co-organizers only, while the period
// takes payments (open or drawn). Members who cannot get a push, have
// reminders turned off, already paid or were reminded within
// ReminderCooldown are skipped and listed.
func (s *ReminderService) Send(ctx context.Context, groupID, periodID, userID uuid.UUID, memberIDs []uuid.UUID) (ReminderResult, error) {
	now := s.clock.Now()
	var res ReminderResult
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, _, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		p, err := s.periods.GetForUpdate(ctx, groupID, periodID)
		if errors.Is(err, repository.ErrNotFound) {
			return model.ErrPeriodNotFound
		}
		if err != nil {
			return err
		}
		if p.Status != model.PeriodStatusOpen && p.Status != model.PeriodStatusDrawn {
			return model.ErrPeriodNotOpen.WithDetail("Period %d is %s.", p.PeriodNo, p.Status)
		}
		targets, err := s.payments.ListReminderTargets(ctx, p.ID, now)
		if err != nil {
			return err
		}
		if targets, err = selectTargets(targets, memberIDs); err != nil {
			return err
		}
		members, _, err := s.memberMap(ctx, groupID)
		if err != nil {
			return err
		}

		res.Skipped = []ReminderSkip{}
		var sent []uuid.UUID
		for _, t := range targets {
			reason, skip := skipReason(t, now)
			if !skip {
				sent = append(sent, t.PaymentID)
				continue
			}
			m, err := s.refs.member(ctx, members[t.MemberID], false)
			if err != nil {
				return err
			}
			res.Skipped = append(res.Skipped, ReminderSkip{Member: m, Reason: reason, WhatsAppPhone: whatsAppPhone(t)})
		}
		res.SentCount = len(sent)
		if len(sent) == 0 {
			return nil
		}
		if err := s.payments.MarkReminded(ctx, sent, now); err != nil {
			return err
		}
		// TODO(phase 7): enqueue push.send to each reminded payer (FR-REM-01).
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionReminderSent,
			EntityType: model.EntityTypePeriod, EntityID: p.ID,
			After: map[string]any{"sent_count": len(sent), "skipped_count": len(res.Skipped)},
		})
	})
	if err != nil {
		return ReminderResult{}, err
	}
	return res, nil
}

// selectTargets keeps the targets of memberIDs, or all of them when
// memberIDs is empty. A member with no payment in the period is
// member_not_found.
func selectTargets(targets []repository.ReminderTarget, memberIDs []uuid.UUID) ([]repository.ReminderTarget, error) {
	if len(memberIDs) == 0 {
		return targets, nil
	}
	wanted := make(map[uuid.UUID]bool, len(memberIDs))
	for _, id := range memberIDs {
		wanted[id] = true
	}
	var out []repository.ReminderTarget
	for _, t := range targets {
		if wanted[t.MemberID] {
			out = append(out, t)
			delete(wanted, t.MemberID)
		}
	}
	if len(wanted) > 0 {
		return nil, model.ErrMemberNotFound.WithDetail("Some members have no payment in this period.")
	}
	return out, nil
}

// skipReason reports why t gets no push at now, checking in the order of
// the most useful reason for the organizer.
func skipReason(t repository.ReminderTarget, now time.Time) (ReminderSkipReason, bool) {
	switch {
	case t.Status == model.PaymentStatusPaid || t.Status == model.PaymentStatusPendingReview:
		return ReminderSkipAlreadyPaid, true
	case t.UserID == nil:
		return ReminderSkipGuest, true
	case !t.NotifyPaymentReminders:
		return ReminderSkipNotificationsOff, true
	case !t.HasDevice:
		return ReminderSkipNoDevice, true
	case t.LastRemindedAt != nil && now.Sub(*t.LastRemindedAt) < ReminderCooldown:
		return ReminderSkipRecentlyReminded, true
	}
	return "", false
}

// whatsAppPhone is the number to message t's payer on: the account's, or a
// guest's when recorded.
func whatsAppPhone(t repository.ReminderTarget) *string {
	if t.UserPhone != nil {
		return t.UserPhone
	}
	return t.GuestPhone
}

// memberMap returns the group's members, former ones included, by ID and
// in slot order.
func (s *ReminderService) memberMap(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]repository.MemberView, []repository.MemberView, error) {
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, nil, err
	}
	out := make(map[uuid.UUID]repository.MemberView, len(views))
	for _, v := range views {
		if _, ok := out[v.Member.ID]; !ok {
			out[v.Member.ID] = v
		}
	}
	return out, views, nil
}

// Recap returns the period's status for the WhatsApp recap. Any member may
// read it; phone numbers are only for organizers and co-organizers. Unpaid
// lists the members whose payment is unpaid or rejected, by slot number.
func (s *ReminderService) Recap(ctx context.Context, groupID, periodID, userID uuid.UUID) (Recap, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return Recap{}, err
	}
	g, err := s.groups.GetByID(ctx, groupID)
	if err != nil {
		return Recap{}, err
	}
	p, err := s.periods.Get(ctx, groupID, periodID)
	if errors.Is(err, repository.ErrNotFound) {
		return Recap{}, model.ErrPeriodNotFound
	}
	if err != nil {
		return Recap{}, err
	}
	r := Recap{Group: g, Period: p, Unpaid: []RecapUnpaid{}}
	if r.Summary, err = s.payments.Summary(ctx, p.ID); err != nil {
		return Recap{}, err
	}
	members, views, err := s.memberMap(ctx, groupID)
	if err != nil {
		return Recap{}, err
	}
	targets, err := s.payments.ListReminderTargets(ctx, p.ID, s.clock.Now())
	if err != nil {
		return Recap{}, err
	}
	phones := me.Role.CanManageGroup()
	for _, t := range targets {
		if t.Status != model.PaymentStatusUnpaid && t.Status != model.PaymentStatusRejected {
			continue
		}
		m, err := s.refs.member(ctx, members[t.MemberID], false)
		if err != nil {
			return Recap{}, err
		}
		u := RecapUnpaid{Member: m}
		if phones {
			u.WhatsAppPhone = whatsAppPhone(t)
		}
		r.Unpaid = append(r.Unpaid, u)
	}
	if r.LastWinner, err = s.lastWinner(ctx, groupID, p.PeriodNo, views); err != nil {
		return Recap{}, err
	}
	if r.QRISImageURL, err = s.refs.presign(ctx, g.QRISImageKey); err != nil {
		return Recap{}, err
	}
	r.QRISMerchantName = merchantName(g.QRISPayload)
	return r, nil
}

// lastWinner returns the winner of the latest drawn period up to periodNo,
// or nil before the first draw. Like the period history, the slot's first
// holder is the winner.
func (s *ReminderService) lastWinner(ctx context.Context, groupID uuid.UUID, periodNo int16, members []repository.MemberView) (*Member, error) {
	periods, err := s.periods.ListViews(ctx, groupID)
	if err != nil {
		return nil, err
	}
	var slotID *uuid.UUID
	for _, v := range periods {
		if v.Period.PeriodNo <= periodNo && v.Period.WinnerSlotID != nil {
			slotID = v.Period.WinnerSlotID
		}
	}
	if slotID == nil {
		return nil, nil
	}
	for _, v := range members {
		if v.SlotID == *slotID {
			m, err := s.refs.member(ctx, v, false)
			if err != nil {
				return nil, err
			}
			return &m, nil
		}
	}
	return nil, nil
}
