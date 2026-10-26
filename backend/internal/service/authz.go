package service

import (
	"context"
	"errors"
	"slices"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

// Role sets for RequireRole; passing none admits every active member.
var (
	managers      = []model.MemberRole{model.MemberRoleOrganizer, model.MemberRoleCoOrganizer}
	organizerOnly = []model.MemberRole{model.MemberRoleOrganizer}
)

// Authz runs the group permission check on every request (PRD §5). Services
// call it rather than controllers, so the rule holds whoever calls them.
type Authz struct {
	groups  *repository.GroupRepository
	members *repository.MemberRepository
}

func NewAuthz(groups *repository.GroupRepository, members *repository.MemberRepository) *Authz {
	return &Authz{groups: groups, members: members}
}

// RequireRole returns userID's active membership in groupID. A user who is
// not a member gets group_not_found, so the group's existence never leaks;
// a member whose role is not in roles gets forbidden_role. No roles admits
// every member.
func (a *Authz) RequireRole(ctx context.Context, groupID, userID uuid.UUID, roles ...model.MemberRole) (model.GroupMember, error) {
	m, err := a.members.GetMembership(ctx, groupID, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.GroupMember{}, model.ErrGroupNotFound
	}
	if err != nil {
		return model.GroupMember{}, err
	}
	if len(roles) > 0 && !slices.Contains(roles, m.Role) {
		return model.GroupMember{}, model.ErrForbiddenRole
	}
	return m, nil
}

// LockGroup row-locks the group and then checks the caller's role, so the
// check and the write that follows see the same organizer. Call it inside
// WithTx.
func (a *Authz) LockGroup(ctx context.Context, groupID, userID uuid.UUID, roles ...model.MemberRole) (model.Group, model.GroupMember, error) {
	g, err := a.groups.GetForUpdate(ctx, groupID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.Group{}, model.GroupMember{}, model.ErrGroupNotFound
	}
	if err != nil {
		return model.Group{}, model.GroupMember{}, err
	}
	m, err := a.RequireRole(ctx, groupID, userID, roles...)
	if err != nil {
		return model.Group{}, model.GroupMember{}, err
	}
	return g, m, nil
}

// requireRunning refuses writes to a completed or closed group, which stays
// read-only in history (FR-GRP-04).
func requireRunning(g model.Group) error {
	if g.IsFinished() {
		return model.ErrGroupNotActive.WithDetail("The group is %s and read-only.", g.Status)
	}
	return nil
}
