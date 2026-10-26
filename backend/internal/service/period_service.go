package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/draw"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

// PeriodDetail is a period as members see it. Summary is nil for periods
// that have not opened, and Winner is nil until the draw. The seed is never
// part of it: it stays sealed until the draw reveals it.
type PeriodDetail struct {
	repository.PeriodView
	Winner  *Member
	Summary *repository.PaymentSummary
}

// PeriodService lists a group's periods (history and schedule).
type PeriodService struct {
	periods  *repository.PeriodRepository
	payments *repository.PaymentRepository
	members  *repository.MemberRepository
	authz    *Authz
	refs     refs
}

func NewPeriodService(
	periods *repository.PeriodRepository,
	payments *repository.PaymentRepository,
	members *repository.MemberRepository,
	users *repository.UserRepository,
	authz *Authz,
	store storage.Storage,
) *PeriodService {
	return &PeriodService{
		periods: periods, payments: payments, members: members, authz: authz,
		refs: refs{users: users, store: store},
	}
}

// List returns every period of the group in order. Any member may read it.
func (s *PeriodService) List(ctx context.Context, groupID, userID uuid.UUID) ([]PeriodDetail, error) {
	if _, err := s.authz.RequireRole(ctx, groupID, userID); err != nil {
		return nil, err
	}
	views, err := s.periods.ListViews(ctx, groupID)
	if err != nil {
		return nil, err
	}
	winners, err := s.winners(ctx, groupID, views)
	if err != nil {
		return nil, err
	}
	out := make([]PeriodDetail, len(views))
	for i, v := range views {
		if out[i], err = s.detail(ctx, v, winners); err != nil {
			return nil, err
		}
	}
	return out, nil
}

// Get returns one period of the group.
func (s *PeriodService) Get(ctx context.Context, groupID, periodID, userID uuid.UUID) (PeriodDetail, error) {
	if _, err := s.authz.RequireRole(ctx, groupID, userID); err != nil {
		return PeriodDetail{}, err
	}
	v, err := s.periods.GetView(ctx, groupID, periodID)
	if errors.Is(err, repository.ErrNotFound) {
		return PeriodDetail{}, model.ErrPeriodNotFound
	}
	if err != nil {
		return PeriodDetail{}, err
	}
	winners, err := s.winners(ctx, groupID, []repository.PeriodView{v})
	if err != nil {
		return PeriodDetail{}, err
	}
	return s.detail(ctx, v, winners)
}

// winners maps winning slot IDs to the member holding the slot, loading
// members only when some period has a winner.
func (s *PeriodService) winners(ctx context.Context, groupID uuid.UUID, views []repository.PeriodView) (map[uuid.UUID]Member, error) {
	out := map[uuid.UUID]Member{}
	if !hasWinner(views) {
		return out, nil
	}
	members, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, err
	}
	for _, v := range members {
		if _, ok := out[v.SlotID]; ok {
			continue
		}
		m, err := s.refs.member(ctx, v, false)
		if err != nil {
			return nil, err
		}
		out[v.SlotID] = m
	}
	return out, nil
}

func hasWinner(views []repository.PeriodView) bool {
	for _, v := range views {
		if v.Period.WinnerSlotID != nil {
			return true
		}
	}
	return false
}

func (s *PeriodService) detail(ctx context.Context, v repository.PeriodView, winners map[uuid.UUID]Member) (PeriodDetail, error) {
	d := PeriodDetail{PeriodView: v}
	if v.Period.WinnerSlotID != nil {
		if w, ok := winners[*v.Period.WinnerSlotID]; ok {
			d.Winner = &w
		}
	}
	if v.Period.Status != model.PeriodStatusUpcoming {
		sum, err := s.payments.Summary(ctx, v.Period.ID)
		if err != nil {
			return PeriodDetail{}, err
		}
		d.Summary = &sum
	}
	return d, nil
}

// periodOpener opens periods: starting a group opens period 1, and recording
// a payout opens the next one.
type periodOpener struct {
	periods  *repository.PeriodRepository
	payments *repository.PaymentRepository
	activity *Activity
}

// open moves p from upcoming to open, inside the caller's transaction with
// g locked. A random group's period gets a fresh seed: only its hash is
// published, before any payment of the period exists, let alone is approved
// (BR-04); the seed stays sealed in period_seeds until the draw. Every active
// slot holder gets an unpaid payment of their share of the amount, and
// period.opened is logged. actor is nil for system openings.
func (o periodOpener) open(ctx context.Context, g model.Group, p model.Period, actor *uuid.UUID, now time.Time) (model.Period, error) {
	var seedHash *string
	var seedHex string
	if g.UsesSeed() {
		seed, h, err := draw.Commit()
		if err != nil {
			return model.Period{}, err
		}
		seedHash, seedHex = &h, seed
	}
	opened, err := o.periods.Open(ctx, p.ID, seedHash)
	if errors.Is(err, repository.ErrNotFound) {
		return model.Period{}, model.ErrPeriodNotOpen.WithDetail("Period %d is %s and cannot open.", p.PeriodNo, p.Status)
	}
	if err != nil {
		return model.Period{}, err
	}
	if seedHash != nil {
		if err := o.periods.SealSeed(ctx, p.ID, seedHex, now); err != nil {
			return model.Period{}, err
		}
	}

	holders, err := o.payments.ListSlotHolders(ctx, g.ID)
	if err != nil {
		return model.Period{}, err
	}
	payments := make([]model.Payment, len(holders))
	for i, h := range holders {
		payments[i] = model.Payment{SlotID: h.SlotID, MemberID: h.MemberID, Amount: h.ShareOf(g.Amount)}
	}
	if err := o.payments.CreateAll(ctx, g.ID, p.ID, payments, now); err != nil {
		return model.Period{}, err
	}

	after := map[string]any{"status": opened.Status, "period_no": opened.PeriodNo, "due_date": opened.DueDate.Format(dateLayout), "payment_count": len(payments)}
	if seedHash != nil {
		after["seed_hash"] = *seedHash
	}
	err = o.activity.Record(ctx, Entry{
		GroupID: g.ID, Actor: actor, Action: model.ActionPeriodOpened,
		EntityType: model.EntityTypePeriod, EntityID: p.ID,
		Before: map[string]any{"status": p.Status}, After: after,
	})
	return opened, err
}
