package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// errTransferNotFound is the 404 for an unknown transfer; the spec has no
// dedicated code for it.
var errTransferNotFound = model.ErrNotFound.WithDetail("Ownership transfer not found.")

// OwnershipTransfer is a transfer with the organizer who offered it and the
// member it was offered to.
type OwnershipTransfer struct {
	Transfer model.OwnershipTransfer
	From     UserRef
	To       Member
}

// OwnershipService hands a group to a new organizer, who must accept (BR-08).
type OwnershipService struct {
	tx        *repository.TxManager
	groups    *repository.GroupRepository
	members   *repository.MemberRepository
	leaves    *repository.LeaveRequestRepository
	transfers *repository.OwnershipTransferRepository
	authz     *Authz
	activity  *Activity
	refs      refs
	clock     clock.Clock
}

func NewOwnershipService(
	tx *repository.TxManager,
	groups *repository.GroupRepository,
	members *repository.MemberRepository,
	leaves *repository.LeaveRequestRepository,
	transfers *repository.OwnershipTransferRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
) *OwnershipService {
	return &OwnershipService{
		tx: tx, groups: groups, members: members, leaves: leaves, transfers: transfers,
		authz: authz, activity: activity, refs: refs{users: users, store: store}, clock: clk,
	}
}

// Offer offers the organizer role to another member with an account. It
// expires after 7 days; a group has one pending offer at a time
// (pending_request_exists).
func (s *OwnershipService) Offer(ctx context.Context, groupID, userID, toMemberID uuid.UUID) (OwnershipTransfer, error) {
	now := s.clock.Now()
	var t model.OwnershipTransfer
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID, organizerOnly...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		to, err := s.members.GetForUpdate(ctx, groupID, toMemberID)
		if errors.Is(err, repository.ErrNotFound) || (err == nil && !to.IsActive()) {
			return model.ErrMemberNotFound
		}
		if err != nil {
			return err
		}
		switch {
		case to.ID == me.ID:
			return invalidTarget("You are already the organizer.")
		case to.IsGuest():
			return invalidTarget("The new organizer needs an account; send the guest a claim link first.")
		}
		if err := s.transfers.ExpireOverdue(ctx, groupID, now); err != nil {
			return err
		}
		t, err = s.transfers.Create(ctx, model.OwnershipTransfer{
			ID: uuid.Must(uuid.NewV7()), GroupID: groupID, FromUserID: userID, ToMemberID: to.ID,
			ExpiresAt: now.Add(model.OwnershipTransferTTL),
		}, now)
		if errors.Is(err, repository.ErrDuplicate) {
			return model.ErrPendingRequestExists
		}
		if err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionOwnershipOffered,
			EntityType: model.EntityTypeMember, EntityID: to.ID,
		})
	})
	if err != nil {
		return OwnershipTransfer{}, err
	}
	return s.view(ctx, t)
}

func invalidTarget(msg string) error {
	return model.NewValidationError(model.FieldError{Field: "to_member_id", Code: model.FieldInvalidChoice, Message: msg})
}

// Accept makes the caller the organizer and the previous organizer a plain
// member, in one transaction with ownership.transferred. Only the member the
// transfer was offered to can accept.
func (s *OwnershipService) Accept(ctx context.Context, groupID, userID, transferID uuid.UUID) (OwnershipTransfer, error) {
	return s.respond(ctx, groupID, userID, transferID, func(ctx context.Context, g model.Group, me model.GroupMember, t model.OwnershipTransfer) (model.OwnershipTransfer, error) {
		old, err := s.members.GetMembership(ctx, groupID, t.FromUserID)
		if errors.Is(err, repository.ErrNotFound) || (err == nil && !old.IsOrganizer()) || g.OrganizerID != t.FromUserID {
			return model.OwnershipTransfer{}, model.ErrRequestNotPending.WithDetail("The offering organizer no longer runs the group.")
		}
		if err != nil {
			return model.OwnershipTransfer{}, err
		}
		// Demote first: the database allows one active organizer per group.
		if err := s.members.SetRole(ctx, old.ID, model.MemberRoleMember); err != nil {
			return model.OwnershipTransfer{}, err
		}
		if err := s.members.SetRole(ctx, me.ID, model.MemberRoleOrganizer); err != nil {
			return model.OwnershipTransfer{}, err
		}
		if err := s.groups.SetOrganizer(ctx, groupID, userID); err != nil {
			return model.OwnershipTransfer{}, err
		}
		// An organizer cannot leave, so a request they made as a member goes.
		if err := s.leaves.CancelPending(ctx, groupID, &me.ID); err != nil {
			return model.OwnershipTransfer{}, err
		}
		t, err = s.transfers.Respond(ctx, transferID, model.OwnershipTransferStatusAccepted, s.clock.Now())
		if err != nil {
			return model.OwnershipTransfer{}, err
		}
		return t, s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionOwnershipTransferred,
			EntityType: model.EntityTypeGroup, EntityID: groupID,
			Before: map[string]any{"organizer_id": t.FromUserID}, After: map[string]any{"organizer_id": userID},
		})
	})
}

// Decline turns the offer down; the organizer stays.
func (s *OwnershipService) Decline(ctx context.Context, groupID, userID, transferID uuid.UUID) (OwnershipTransfer, error) {
	return s.respond(ctx, groupID, userID, transferID, func(ctx context.Context, _ model.Group, me model.GroupMember, _ model.OwnershipTransfer) (model.OwnershipTransfer, error) {
		t, err := s.transfers.Respond(ctx, transferID, model.OwnershipTransferStatusDeclined, s.clock.Now())
		if err != nil {
			return model.OwnershipTransfer{}, err
		}
		return t, s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionOwnershipDeclined,
			EntityType: model.EntityTypeMember, EntityID: me.ID,
		})
	})
}

// respond locks the group and a pending transfer offered to the caller, and
// runs decide on it. A transfer past its deadline is marked expired and the
// caller gets request_not_pending.
func (s *OwnershipService) respond(
	ctx context.Context, groupID, userID, transferID uuid.UUID,
	decide func(context.Context, model.Group, model.GroupMember, model.OwnershipTransfer) (model.OwnershipTransfer, error),
) (OwnershipTransfer, error) {
	now := s.clock.Now()
	var t model.OwnershipTransfer
	expired := false
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID)
		if err != nil {
			return err
		}
		t, err = s.transfers.GetForUpdate(ctx, groupID, transferID)
		if errors.Is(err, repository.ErrNotFound) {
			return errTransferNotFound
		}
		if err != nil {
			return err
		}
		if t.ToMemberID != me.ID {
			return model.ErrForbiddenRole.WithDetail("The transfer was offered to another member.")
		}
		if !t.IsPending() {
			return model.ErrRequestNotPending
		}
		if t.IsExpired(now) {
			// Return nil so the expiry commits; the error follows the
			// transaction.
			expired = true
			_, err := s.transfers.Respond(ctx, transferID, model.OwnershipTransferStatusExpired, now)
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		t, err = decide(ctx, g, me, t)
		return err
	})
	if err != nil {
		return OwnershipTransfer{}, err
	}
	if expired {
		return OwnershipTransfer{}, model.ErrRequestNotPending.WithDetail("The transfer has expired.")
	}
	return s.view(ctx, t)
}

func (s *OwnershipService) view(ctx context.Context, t model.OwnershipTransfer) (OwnershipTransfer, error) {
	from, err := s.refs.user(ctx, t.FromUserID)
	if err != nil {
		return OwnershipTransfer{}, err
	}
	v, err := s.members.GetView(ctx, t.GroupID, t.ToMemberID)
	if err != nil {
		return OwnershipTransfer{}, err
	}
	to, err := s.refs.member(ctx, v, false)
	if err != nil {
		return OwnershipTransfer{}, err
	}
	return OwnershipTransfer{Transfer: t, From: from, To: to}, nil
}
