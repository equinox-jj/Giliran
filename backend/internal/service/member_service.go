package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// Guest name length limits (group_members.guest_name CHECK).
const (
	guestNameMinLen = 2
	guestNameMaxLen = 50
)

// claimTokenBytes is the entropy of a claim token.
const claimTokenBytes = 32

// Member is a member with its slot and a presigned avatar URL. GuestPhone is
// cleared unless the caller is an organizer or co-organizer.
type Member struct {
	repository.MemberView
	AvatarURL *string
}

// DisplayName is the account's name, or the guest name.
func (m Member) DisplayName() string {
	if m.Member.GuestName != nil {
		return *m.Member.GuestName
	}
	if m.UserName != nil {
		return *m.UserName
	}
	return ""
}

// InvitePreview is what an invite link shows before joining.
type InvitePreview struct {
	Group         model.Group
	Organizer     UserRef
	FilledSlots   int
	CanJoin       bool
	AlreadyMember bool
}

// ClaimLink is a link a guest opens to take over their slot.
type ClaimLink struct {
	URL       string
	ExpiresAt time.Time
}

// GuestChange lists the guest fields to change. Phone is changed only when
// SetPhone is true; a nil Phone then removes it.
type GuestChange struct {
	Name     *string
	SetPhone bool
	Phone    *string
}

// MemberService handles who is in a group: invites, joining, guests, claim
// links and removal (features 17–20).
type MemberService struct {
	tx        *repository.TxManager
	groups    *repository.GroupRepository
	members   *repository.MemberRepository
	leaves    *repository.LeaveRequestRepository
	transfers *repository.OwnershipTransferRepository
	authz     *Authz
	activity  *Activity
	refs      refs
	clock     clock.Clock
	baseURL   string
}

func NewMemberService(
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
	cfg *config.Config,
) *MemberService {
	return &MemberService{
		tx: tx, groups: groups, members: members, leaves: leaves, transfers: transfers,
		authz: authz, activity: activity, refs: refs{users: users, store: store}, clock: clk,
		baseURL: strings.TrimRight(cfg.App.PublicBaseURL, "/"),
	}
}

// PreviewInvite shows the group behind an invite code to a signed-in user.
func (s *MemberService) PreviewInvite(ctx context.Context, userID uuid.UUID, code string) (InvitePreview, error) {
	g, err := s.groupByInvite(ctx, code)
	if err != nil {
		return InvitePreview{}, err
	}
	p := InvitePreview{Group: g}
	if p.Organizer, err = s.refs.user(ctx, g.OrganizerID); err != nil {
		return InvitePreview{}, err
	}
	if p.FilledSlots, err = s.groups.CountFilledSlots(ctx, g.ID); err != nil {
		return InvitePreview{}, err
	}
	_, err = s.members.GetMembership(ctx, g.ID, userID)
	switch {
	case err == nil:
		p.AlreadyMember = true
	case !errors.Is(err, repository.ErrNotFound):
		return InvitePreview{}, err
	}
	if !p.AlreadyMember && !g.IsFinished() {
		_, err := s.groups.LowestFreeSlot(ctx, g.ID)
		switch {
		case err == nil:
			p.CanJoin = true
		case !errors.Is(err, repository.ErrNotFound):
			return InvitePreview{}, err
		}
	}
	return p, nil
}

func (s *MemberService) groupByInvite(ctx context.Context, code string) (model.Group, error) {
	g, err := s.groups.GetByInviteCode(ctx, strings.ToUpper(code))
	if errors.Is(err, repository.ErrNotFound) {
		return model.Group{}, model.ErrInviteNotFound
	}
	return g, err
}

// Join adds the caller to the group behind an invite code, on the lowest
// free slot (FR-MEM-02). Slots that already won stay taken, so a running
// group can be joined only where a member left before winning.
func (s *MemberService) Join(ctx context.Context, userID uuid.UUID, code string) (Member, error) {
	g, err := s.groupByInvite(ctx, code)
	if err != nil {
		return Member{}, err
	}
	now := s.clock.Now()
	var m model.GroupMember
	err = s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, err := s.groups.GetForUpdate(ctx, g.ID)
		if err != nil {
			return err
		}
		// The code may have been reset while we waited for the lock.
		if g.InviteCode != strings.ToUpper(code) {
			return model.ErrInviteNotFound
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		if _, err := s.members.GetMembership(ctx, g.ID, userID); err == nil {
			return model.ErrAlreadyMember
		} else if !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		if m, err = addToFreeSlot(ctx, s.groups, s.members, g.ID, model.GroupMember{UserID: &userID, Role: model.MemberRoleMember}, now); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: g.ID, Actor: &userID, Action: model.ActionMemberJoined,
			EntityType: model.EntityTypeMember, EntityID: m.ID,
		})
	})
	if err != nil {
		return Member{}, err
	}
	return s.view(ctx, g.ID, m.ID, false)
}

// List returns the group's members by slot number; includeInactive adds those
// who left or were removed.
func (s *MemberService) List(ctx context.Context, groupID, userID uuid.UUID, includeInactive bool) ([]Member, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return nil, err
	}
	views, err := s.members.ListViews(ctx, groupID, includeInactive)
	if err != nil {
		return nil, err
	}
	return s.refs.members(ctx, views, me.Role.CanManageGroup())
}

// Get returns one member of the group.
func (s *MemberService) Get(ctx context.Context, groupID, userID, memberID uuid.UUID) (Member, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return Member{}, err
	}
	return s.view(ctx, groupID, memberID, me.Role.CanManageGroup())
}

func (s *MemberService) view(ctx context.Context, groupID, memberID uuid.UUID, guestPhones bool) (Member, error) {
	v, err := s.members.GetView(ctx, groupID, memberID)
	if errors.Is(err, repository.ErrNotFound) {
		return Member{}, model.ErrMemberNotFound
	}
	if err != nil {
		return Member{}, err
	}
	return s.refs.member(ctx, v, guestPhones)
}

// AddGuest adds a member without an account on the lowest free slot
// (FR-MEM-03). The phone, if given, lets the guest claim the slot at sign-up.
func (s *MemberService) AddGuest(ctx context.Context, groupID, userID uuid.UUID, name string, phone *string) (Member, error) {
	name, err := trimmedLength("name", name, guestNameMinLen, guestNameMaxLen)
	if err != nil {
		return Member{}, err
	}
	if phone, err = normalizeOptionalPhone(phone); err != nil {
		return Member{}, err
	}
	now := s.clock.Now()
	var m model.GroupMember
	err = s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, _, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		guest := model.GroupMember{GuestName: &name, GuestPhone: phone, Role: model.MemberRoleMember}
		if m, err = addToFreeSlot(ctx, s.groups, s.members, groupID, guest, now); err != nil {
			return err
		}
		// The phone stays out of the log: only organizers may see it.
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionMemberGuestAdded,
			EntityType: model.EntityTypeMember, EntityID: m.ID, After: map[string]any{"name": name},
		})
	})
	if err != nil {
		return Member{}, err
	}
	return s.view(ctx, groupID, m.ID, true)
}

func normalizeOptionalPhone(phone *string) (*string, error) {
	if phone == nil {
		return nil, nil
	}
	p, err := utils.NormalizePhone("phone", *phone)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// UpdateGuest changes a guest's name or phone. Members with an account are
// member_not_found here: their name is their own.
func (s *MemberService) UpdateGuest(ctx context.Context, groupID, userID, memberID uuid.UUID, c GuestChange) (Member, error) {
	if c.Name != nil {
		name, err := trimmedLength("name", *c.Name, guestNameMinLen, guestNameMaxLen)
		if err != nil {
			return Member{}, err
		}
		c.Name = &name
	}
	if c.SetPhone {
		var err error
		if c.Phone, err = normalizeOptionalPhone(c.Phone); err != nil {
			return Member{}, err
		}
	}
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, _, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		m, err := s.activeMember(ctx, groupID, memberID)
		if err != nil {
			return err
		}
		if !m.IsGuest() {
			return model.ErrMemberNotFound.WithDetail("Only guests can be edited.")
		}
		name, phone := *m.GuestName, m.GuestPhone
		before, after := map[string]any{}, map[string]any{}
		if c.Name != nil && *c.Name != name {
			before["name"], after["name"] = name, *c.Name
			name = *c.Name
		}
		if c.SetPhone && !equalPtr(c.Phone, phone) {
			// Whether there is a phone, not the number: only organizers
			// may see it.
			before["has_phone"], after["has_phone"] = phone != nil, c.Phone != nil
			phone = c.Phone
		}
		if len(after) == 0 {
			return nil
		}
		if _, err := s.members.UpdateGuest(ctx, memberID, name, phone); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionMemberGuestUpdated,
			EntityType: model.EntityTypeMember, EntityID: memberID, Before: before, After: after,
		})
	})
	if err != nil {
		return Member{}, err
	}
	return s.view(ctx, groupID, memberID, true)
}

func equalPtr(a, b *string) bool {
	if a == nil || b == nil {
		return a == b
	}
	return *a == *b
}

// activeMember row-locks an active member of the group.
func (s *MemberService) activeMember(ctx context.Context, groupID, memberID uuid.UUID) (model.GroupMember, error) {
	m, err := s.members.GetForUpdate(ctx, groupID, memberID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.GroupMember{}, model.ErrMemberNotFound
	}
	if err != nil {
		return model.GroupMember{}, err
	}
	if !m.IsActive() {
		return model.GroupMember{}, model.ErrMemberNotFound.WithDetail("The member already left the group.")
	}
	return m, nil
}

// Remove takes a member out of the group and frees their slot (FR-MEM-06).
// Only members who have not won and have no recorded payment in an open
// period can be removed (obligations_outstanding); the organizer never can.
func (s *MemberService) Remove(ctx context.Context, groupID, userID, memberID uuid.UUID) error {
	now := s.clock.Now()
	return s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		m, err := s.activeMember(ctx, groupID, memberID)
		if err != nil {
			return err
		}
		if m.IsOrganizer() {
			return model.ErrOrganizerCannotLeave
		}
		if m.ID == me.ID {
			return model.ErrForbiddenRole.WithDetail("Ask to leave the group instead.")
		}
		won, err := s.members.HasWon(ctx, memberID)
		if err != nil {
			return err
		}
		if won {
			return model.ErrObligationsOutstanding.WithDetail("This member has already won and still owes the remaining periods.")
		}
		paid, err := s.members.HasPaymentsInOpenPeriods(ctx, memberID)
		if err != nil {
			return err
		}
		if paid {
			return model.ErrObligationsOutstanding.WithDetail("This member has a recorded payment in the open period.")
		}
		return deactivateMember(ctx, s.members, s.leaves, s.transfers, s.activity, groupID, userID, m, model.MemberStatusRemoved, model.ActionMemberRemoved, now)
	})
}

// deactivateMember marks m left or removed, cancels their pending leave
// request and any ownership transfer offered to them, and logs action.
func deactivateMember(
	ctx context.Context,
	members *repository.MemberRepository,
	leaves *repository.LeaveRequestRepository,
	transfers *repository.OwnershipTransferRepository,
	activity *Activity,
	groupID, actor uuid.UUID, m model.GroupMember, status model.MemberStatus, action model.Action, now time.Time,
) error {
	if _, err := members.Deactivate(ctx, m.ID, status, now); err != nil {
		return err
	}
	if err := leaves.CancelPending(ctx, groupID, &m.ID); err != nil {
		return err
	}
	if err := transfers.CancelPending(ctx, groupID, &m.ID); err != nil {
		return err
	}
	return activity.Record(ctx, Entry{
		GroupID: groupID, Actor: &actor, Action: action, EntityType: model.EntityTypeMember, EntityID: m.ID,
		Before: map[string]any{"status": m.Status}, After: map[string]any{"status": status},
	})
}

// CreateClaimLink makes a 7-day link a guest opens to take over their slot
// with an account (FR-MEM-04). A new link replaces the previous one.
func (s *MemberService) CreateClaimLink(ctx context.Context, groupID, userID, memberID uuid.UUID) (ClaimLink, error) {
	token, err := security.RandomToken(claimTokenBytes)
	if err != nil {
		return ClaimLink{}, err
	}
	expires := s.clock.Now().Add(model.ClaimLinkTTL)
	err = s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, _, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		m, err := s.activeMember(ctx, groupID, memberID)
		if err != nil {
			return err
		}
		if !m.IsGuest() {
			return model.ErrMemberNotFound.WithDetail("Only guests have claim links.")
		}
		if err := s.members.SetClaimToken(ctx, memberID, security.SHA256Hex([]byte(token)), expires); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionMemberClaimLinkCreated,
			EntityType: model.EntityTypeMember, EntityID: memberID,
		})
	})
	if err != nil {
		return ClaimLink{}, err
	}
	return ClaimLink{URL: s.baseURL + "/c/" + token, ExpiresAt: expires}, nil
}

// Claim moves the guest row behind a claim token onto the caller's account,
// so the slot keeps its payments and history (FR-MEM-04).
func (s *MemberService) Claim(ctx context.Context, userID uuid.UUID, token string) (Member, error) {
	now := s.clock.Now()
	var m model.GroupMember
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		guest, err := s.members.GetByClaimTokenHashForUpdate(ctx, security.SHA256Hex([]byte(token)))
		if errors.Is(err, repository.ErrNotFound) {
			return model.ErrClaimNotFound
		}
		if err != nil {
			return err
		}
		if !guest.IsGuest() || !guest.IsActive() || guest.ClaimTokenExpiresAt == nil || !now.Before(*guest.ClaimTokenExpiresAt) {
			return model.ErrClaimNotFound
		}
		g, err := s.groups.GetByID(ctx, guest.GroupID)
		if err != nil {
			return err
		}
		if g.IsFinished() {
			return model.ErrClaimNotFound
		}
		m, err = claimGuest(ctx, s.members, s.activity, guest, userID)
		if errors.Is(err, repository.ErrDuplicate) {
			return model.ErrAlreadyMember
		}
		return err
	})
	if err != nil {
		return Member{}, err
	}
	return s.view(ctx, m.GroupID, m.ID, false)
}

// claimGuest moves guest onto userID's account and logs it. A user already in
// the group is repository.ErrDuplicate.
func claimGuest(ctx context.Context, members *repository.MemberRepository, activity *Activity, guest model.GroupMember, userID uuid.UUID) (model.GroupMember, error) {
	m, err := members.ClaimGuest(ctx, guest.ID, userID)
	if err != nil {
		return model.GroupMember{}, err
	}
	err = activity.Record(ctx, Entry{
		GroupID: guest.GroupID, Actor: &userID, Action: model.ActionMemberGuestClaimed,
		EntityType: model.EntityTypeMember, EntityID: guest.ID,
		Before: map[string]any{"name": valueOf(guest.GuestName)},
	})
	return m, err
}

// claimGuestsByPhone gives userID every guest slot in a running group whose
// phone matches theirs (FR-MEM-04 auto-claim). Within one group only the
// earliest such guest is claimed, since a user holds one membership per
// group. Call it inside WithTx. If the user joined one of those groups
// concurrently it returns repository.ErrDuplicate, and a retry skips that
// group.
func claimGuestsByPhone(ctx context.Context, members *repository.MemberRepository, activity *Activity, userID uuid.UUID, phone string) error {
	guests, err := members.ListClaimableGuestsByPhone(ctx, phone, userID)
	if err != nil {
		return err
	}
	claimed := map[uuid.UUID]bool{}
	for _, g := range guests {
		if claimed[g.GroupID] {
			continue
		}
		if _, err := claimGuest(ctx, members, activity, g, userID); err != nil {
			return err
		}
		claimed[g.GroupID] = true
	}
	return nil
}
