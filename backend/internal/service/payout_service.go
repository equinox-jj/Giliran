package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/images"
)

// errNoPayout is a period without a payout record. The spec has no
// dedicated code for it.
var errNoPayout = model.ErrNotFound.WithDetail("No payout is recorded for this period.")

// PayoutView is a payout as the caller sees it. ProofURL is set only for
// the winner and organizers, like payment proofs.
type PayoutView struct {
	Payout     model.Payout
	Winner     Member
	RecordedBy UserRef
	ProofURL   *string
}

// PayoutService records the pot handed to each period's winner and the
// winner's confirmation (FR-PAY-05). Recording a payout closes the period
// and opens the next one, or completes the group after the last.
type PayoutService struct {
	tx        *repository.TxManager
	groups    *repository.GroupRepository
	periods   *repository.PeriodRepository
	payouts   *repository.PayoutRepository
	members   *repository.MemberRepository
	authz     *Authz
	activity  *Activity
	opener    periodOpener
	refs      refs
	store     storage.Storage
	clock     clock.Clock
	log       *slog.Logger
	maxUpload int
}

func NewPayoutService(
	tx *repository.TxManager,
	groups *repository.GroupRepository,
	periods *repository.PeriodRepository,
	payments *repository.PaymentRepository,
	payouts *repository.PayoutRepository,
	members *repository.MemberRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
	log *slog.Logger,
	cfg *config.Config,
) *PayoutService {
	return &PayoutService{
		tx: tx, groups: groups, periods: periods, payouts: payouts, members: members, authz: authz, activity: activity,
		opener: periodOpener{periods: periods, payments: payments, activity: activity},
		refs:   refs{users: users, store: store}, store: store, clock: clk, log: log, maxUpload: cfg.MinIO.UploadMaxBytes,
	}
}

// Get returns the payout of a period. Any member may read it.
func (s *PayoutService) Get(ctx context.Context, groupID, periodID, userID uuid.UUID) (PayoutView, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return PayoutView{}, err
	}
	if _, err := s.periods.Get(ctx, groupID, periodID); errors.Is(err, repository.ErrNotFound) {
		return PayoutView{}, model.ErrPeriodNotFound
	} else if err != nil {
		return PayoutView{}, err
	}
	p, err := s.payouts.GetByPeriod(ctx, periodID)
	if errors.Is(err, repository.ErrNotFound) {
		return PayoutView{}, errNoPayout
	}
	if err != nil {
		return PayoutView{}, err
	}
	return s.view(ctx, groupID, p, me)
}

// Record stores that the pot of a drawn period went to its winner, with an
// optional transfer proof and note. Organizers and co-organizers only. The
// period closes, and in the same transaction the next period opens (its
// seed hash published and its payments created) or, after the last period,
// the group completes.
func (s *PayoutService) Record(ctx context.Context, groupID, periodID, userID uuid.UUID, proof []byte, note *string) (PayoutView, error) {
	if note != nil {
		n, err := trimmedLength("note", *note, 0, model.MaxNoteLength)
		if err != nil {
			return PayoutView{}, err
		}
		note = &n
		if n == "" {
			note = nil
		}
	}
	// Check who may record first, so nobody else gets an object stored.
	me, err := s.authz.RequireRole(ctx, groupID, userID, managers...)
	if err != nil {
		return PayoutView{}, err
	}
	payoutID := uuid.Must(uuid.NewV7())
	var key *string
	if len(proof) > 0 {
		k, err := s.storeProof(ctx, groupID, periodID, payoutID, proof)
		if err != nil {
			return PayoutView{}, err
		}
		key = &k
	}

	var p model.Payout
	err = s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, _, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if !g.IsActive() {
			return model.ErrGroupNotActive.WithDetail("The group is %s.", g.Status)
		}
		period, err := s.periods.GetForUpdate(ctx, groupID, periodID)
		if errors.Is(err, repository.ErrNotFound) {
			return model.ErrPeriodNotFound
		}
		if err != nil {
			return err
		}
		switch period.Status {
		case model.PeriodStatusDrawn:
		case model.PeriodStatusClosed:
			return model.ErrPayoutAlreadyRecorded
		default:
			return model.ErrPeriodNotOpen.WithDetail("Period %d has not been drawn yet.", period.PeriodNo)
		}
		winner, err := s.winner(ctx, groupID, *period.WinnerSlotID)
		if err != nil {
			return err
		}

		now := s.clock.Now()
		p, err = s.payouts.Create(ctx, model.Payout{
			ID: payoutID, PeriodID: period.ID, WinnerMemberID: winner.ID, Amount: g.TotalPot(),
			ProofKey: key, Note: note, RecordedBy: userID,
		}, now)
		if errors.Is(err, repository.ErrDuplicate) {
			return model.ErrPayoutAlreadyRecorded
		}
		if err != nil {
			return err
		}
		closed, err := s.periods.Close(ctx, period.ID)
		if err != nil {
			return err
		}

		after := map[string]any{
			"period_id": period.ID, "period_no": period.PeriodNo, "period_status": closed.Status,
			"winner_member_id": winner.ID, "amount": p.Amount, "has_proof": key != nil,
		}
		if note != nil {
			after["note"] = *note
		}
		last := period.PeriodNo >= g.TotalSlots
		if last {
			// DB_SCHEME §7 has no group.completed action, so the payout that
			// completes the group records it.
			completed, err := s.groups.Complete(ctx, g.ID, now)
			if err != nil {
				return err
			}
			after["group_status"] = completed.Status
		}
		// TODO(phase 7): enqueue push.send to the winner.
		if err := s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionPayoutRecorded,
			EntityType: model.EntityTypePayout, EntityID: p.ID,
			Before: map[string]any{"period_status": period.Status}, After: after,
		}); err != nil {
			return err
		}
		if last {
			return nil
		}
		next, err := s.periods.GetByNo(ctx, groupID, period.PeriodNo+1)
		if err != nil {
			return err
		}
		_, err = s.opener.open(ctx, g, next, &userID, now)
		return err
	})
	if err != nil {
		if key != nil {
			deleteOrphan(ctx, s.store, s.log, *key)
		}
		return PayoutView{}, err
	}
	return s.view(ctx, groupID, p, me)
}

// storeProof re-encodes a transfer proof, which drops its metadata, and
// stores it under the payout.
func (s *PayoutService) storeProof(ctx context.Context, groupID, periodID, payoutID uuid.UUID, data []byte) (string, error) {
	if len(data) > s.maxUpload {
		return "", model.ErrFileTooLarge
	}
	jpg, err := images.Proof(data)
	if errors.Is(err, images.ErrUnsupported) {
		return "", model.ErrUnsupportedMediaType
	}
	if err != nil {
		return "", err
	}
	if len(jpg) > model.MaxProofSizeBytes {
		return "", model.ErrFileTooLarge
	}
	key := fmt.Sprintf("payouts/%s/%s/%s.jpg", groupID, periodID, payoutID)
	if err := s.store.Put(ctx, key, images.JPEG, bytes.NewReader(jpg), int64(len(jpg))); err != nil {
		return "", err
	}
	return key, nil
}

// winner returns the member holding the winning slot: its active holder, or
// the earliest past one when the winner has since left.
func (s *PayoutService) winner(ctx context.Context, groupID, slotID uuid.UUID) (model.GroupMember, error) {
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return model.GroupMember{}, err
	}
	h, ok := slotHolders(views)[slotID]
	if !ok {
		return model.GroupMember{}, fmt.Errorf("payout: winning slot %s has no holder", slotID)
	}
	return h.Member, nil
}

// Confirm records that the winner received the pot. Only the winner can
// confirm, also after the group completed; confirming twice returns the
// payout unchanged.
func (s *PayoutService) Confirm(ctx context.Context, groupID, periodID, userID uuid.UUID) (PayoutView, error) {
	var me model.GroupMember
	var p model.Payout
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if _, me, err = s.authz.LockGroup(ctx, groupID, userID); err != nil {
			return err
		}
		if _, err := s.periods.Get(ctx, groupID, periodID); errors.Is(err, repository.ErrNotFound) {
			return model.ErrPeriodNotFound
		} else if err != nil {
			return err
		}
		current, err := s.payouts.GetByPeriod(ctx, periodID)
		if errors.Is(err, repository.ErrNotFound) {
			return errNoPayout
		}
		if err != nil {
			return err
		}
		if current.WinnerMemberID != me.ID {
			return model.ErrForbiddenRole.WithDetail("Only the winner can confirm the payout.")
		}
		if current.IsConfirmed() {
			p = current
			return nil
		}
		if p, err = s.payouts.Confirm(ctx, current.ID, userID, s.clock.Now()); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionPayoutConfirmed,
			EntityType: model.EntityTypePayout, EntityID: p.ID,
			Before: map[string]any{"confirmed": false}, After: map[string]any{"confirmed": true},
		})
	})
	if err != nil {
		return PayoutView{}, err
	}
	return s.view(ctx, groupID, p, me)
}

func (s *PayoutService) view(ctx context.Context, groupID uuid.UUID, p model.Payout, me model.GroupMember) (PayoutView, error) {
	w, err := s.members.GetView(ctx, groupID, p.WinnerMemberID)
	if err != nil {
		return PayoutView{}, err
	}
	winner, err := s.refs.member(ctx, w, false)
	if err != nil {
		return PayoutView{}, err
	}
	by, err := s.refs.user(ctx, p.RecordedBy)
	if err != nil {
		return PayoutView{}, err
	}
	v := PayoutView{Payout: p, Winner: winner, RecordedBy: by}
	if p.WinnerMemberID == me.ID || me.Role.CanManageGroup() {
		if v.ProofURL, err = s.refs.presign(ctx, p.ProofKey); err != nil {
			return PayoutView{}, err
		}
	}
	return v, nil
}
