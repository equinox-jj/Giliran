package service

import (
	"context"
	"log/slog"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// AccountService deletes accounts (feature 9, FR-AUTH-09).
type AccountService struct {
	pins      *PINService
	groups    *repository.GroupRepository
	users     *repository.UserRepository
	sessions  *repository.SessionRepository
	members   *repository.MemberRepository
	leaves    *repository.LeaveRequestRepository
	transfers *repository.OwnershipTransferRepository
	activity  *Activity
	store     storage.Storage
	clock     clock.Clock
	log       *slog.Logger
}

func NewAccountService(
	pins *PINService,
	groups *repository.GroupRepository,
	users *repository.UserRepository,
	sessions *repository.SessionRepository,
	members *repository.MemberRepository,
	leaves *repository.LeaveRequestRepository,
	transfers *repository.OwnershipTransferRepository,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
	log *slog.Logger,
) *AccountService {
	return &AccountService{
		pins: pins, groups: groups, users: users, sessions: sessions, members: members,
		leaves: leaves, transfers: transfers, activity: activity, store: store, clock: clk, log: log,
	}
}

// Delete removes the account after checking the PIN; a wrong PIN counts
// towards the lock like any other PIN entry. It is blocked while the user
// organizes a draft or active group (organizer_cannot_leave) or is still in
// an active group (obligations_outstanding): a past winner owes the
// remaining periods, and anyone else holds a slot that keeps receiving
// payments and draws, so they leave through a leave request first.
// Memberships of draft groups end and free their slots; completed and
// closed groups keep the history under "Mantan anggota". Personal data is
// cleared (DB_SCHEME §10), every session is revoked and the avatar object is
// deleted.
func (s *AccountService) Delete(ctx context.Context, userID uuid.UUID, pin string) error {
	now := s.clock.Now()
	var avatarKey *string
	err := s.pins.checkPIN(ctx, userID, pin, func(ctx context.Context) error {
		user, err := currentUser(s.users.GetByIDForUpdate(ctx, userID))
		if err != nil {
			return err
		}
		avatarKey = user.AvatarKey
		memberships, err := s.members.ListUserMemberships(ctx, userID)
		if err != nil {
			return err
		}
		for _, m := range memberships {
			if err := checkDeletable(m); err != nil {
				return err
			}
		}
		for _, m := range memberships {
			if m.GroupStatus != model.GroupStatusDraft {
				continue
			}
			// Lock the group like every other membership change.
			if _, err := s.groups.GetForUpdate(ctx, m.Member.GroupID); err != nil {
				return err
			}
			if err := deactivateMember(ctx, s.members, s.leaves, s.transfers, s.activity,
				m.Member.GroupID, userID, m.Member, model.MemberStatusLeft, model.ActionMemberLeft, now); err != nil {
				return err
			}
		}
		if err := s.users.Anonymize(ctx, userID, now); err != nil {
			return err
		}
		_, err = s.sessions.RevokeAll(ctx, userID, model.RevokedReasonAccountDeleted, now)
		return err
	})
	if err != nil {
		return err
	}
	if avatarKey != nil {
		if err := s.store.Delete(context.WithoutCancel(ctx), *avatarKey); err != nil {
			s.log.WarnContext(ctx, "orphaned storage object", "key", *avatarKey, "error", err)
		}
	}
	return nil
}

// checkDeletable refuses deletion while m ties the user to a running group.
func checkDeletable(m repository.Membership) error {
	switch m.GroupStatus {
	case model.GroupStatusDraft:
		if m.Member.IsOrganizer() {
			return model.ErrOrganizerCannotLeave.WithDetail("Transfer ownership or close your groups before deleting the account.")
		}
	case model.GroupStatusActive:
		if m.Member.IsOrganizer() {
			return model.ErrOrganizerCannotLeave.WithDetail("Transfer ownership or close your groups before deleting the account.")
		}
		return model.ErrObligationsOutstanding.WithDetail("Leave your running groups before deleting the account.")
	}
	return nil
}
