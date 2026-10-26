package service

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// errLeaveRequestNotFound is the 404 for an unknown leave request; the spec
// has no dedicated code for it.
var errLeaveRequestNotFound = model.ErrNotFound.WithDetail("Leave request not found.")

// LeaveRequest is a leave request with the member who asked and the
// organizer who reviewed it.
type LeaveRequest struct {
	Request    model.LeaveRequest
	Member     Member
	ReviewedBy *UserRef
}

// LeaveService handles members asking to leave and organizers deciding
// (FR-MEM-05).
type LeaveService struct {
	tx        *repository.TxManager
	members   *repository.MemberRepository
	leaves    *repository.LeaveRequestRepository
	transfers *repository.OwnershipTransferRepository
	authz     *Authz
	activity  *Activity
	refs      refs
	clock     clock.Clock
}

func NewLeaveService(
	tx *repository.TxManager,
	members *repository.MemberRepository,
	leaves *repository.LeaveRequestRepository,
	transfers *repository.OwnershipTransferRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
) *LeaveService {
	return &LeaveService{
		tx: tx, members: members, leaves: leaves, transfers: transfers,
		authz: authz, activity: activity, refs: refs{users: users, store: store}, clock: clk,
	}
}

// List returns leave requests, newest first: every request for organizers
// and co-organizers, only their own for members. A nil status matches all.
func (s *LeaveService) List(ctx context.Context, groupID, userID uuid.UUID, status *model.LeaveRequestStatus) ([]LeaveRequest, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return nil, err
	}
	var only *uuid.UUID
	if !me.Role.CanManageGroup() {
		only = &me.ID
	}
	reqs, err := s.leaves.List(ctx, groupID, only, status)
	if err != nil {
		return nil, err
	}
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, err
	}
	byID := make(map[uuid.UUID]repository.MemberView, len(views))
	for _, v := range views {
		byID[v.Member.ID] = v
	}
	reviewers := map[uuid.UUID]UserRef{}
	out := make([]LeaveRequest, 0, len(reqs))
	for _, r := range reqs {
		v, ok := byID[r.MemberID]
		if !ok {
			// The member's slot was dropped when a draft group shrank.
			continue
		}
		lr := LeaveRequest{Request: r}
		if lr.Member, err = s.refs.member(ctx, v, false); err != nil {
			return nil, err
		}
		if r.ReviewedBy != nil {
			ref, ok := reviewers[*r.ReviewedBy]
			if !ok {
				if ref, err = s.refs.user(ctx, *r.ReviewedBy); err != nil {
					return nil, err
				}
				reviewers[*r.ReviewedBy] = ref
			}
			lr.ReviewedBy = &ref
		}
		out = append(out, lr)
	}
	return out, nil
}

// Request asks the organizer to let the caller leave. The organizer cannot
// leave (organizer_cannot_leave), nor can a past winner who still owes
// payments (obligations_outstanding). One pending request per member.
func (s *LeaveService) Request(ctx context.Context, groupID, userID uuid.UUID, reason *string) (LeaveRequest, error) {
	if reason != nil {
		if r := strings.TrimSpace(*reason); r == "" {
			reason = nil
		} else {
			reason = &r
		}
	}
	now := s.clock.Now()
	var req model.LeaveRequest
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		if me.IsOrganizer() {
			return model.ErrOrganizerCannotLeave
		}
		if err := s.checkObligations(ctx, groupID, me.ID); err != nil {
			return err
		}
		req, err = s.leaves.Create(ctx, model.LeaveRequest{
			ID: uuid.Must(uuid.NewV7()), GroupID: groupID, MemberID: me.ID, Reason: reason,
		}, now)
		if errors.Is(err, repository.ErrDuplicate) {
			return model.ErrPendingRequestExists
		}
		return err
	})
	if err != nil {
		return LeaveRequest{}, err
	}
	return s.view(ctx, req)
}

func (s *LeaveService) checkObligations(ctx context.Context, groupID, memberID uuid.UUID) error {
	owes, err := s.members.HasOutstandingObligations(ctx, groupID, memberID)
	if err != nil {
		return err
	}
	if owes {
		return model.ErrObligationsOutstanding.WithDetail("You have already won; pay the remaining periods first.")
	}
	return nil
}

// Approve lets the member leave: their status becomes left and their slot is
// free again. Obligations are checked again, since a draw may have happened
// since the request.
func (s *LeaveService) Approve(ctx context.Context, groupID, userID, requestID uuid.UUID) (LeaveRequest, error) {
	now := s.clock.Now()
	var req model.LeaveRequest
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		if req, err = s.pending(ctx, groupID, requestID, me); err != nil {
			return err
		}
		m, err := s.members.GetForUpdate(ctx, groupID, req.MemberID)
		if err != nil {
			return err
		}
		if !m.IsActive() {
			return model.ErrRequestNotPending
		}
		if m.IsOrganizer() {
			return model.ErrOrganizerCannotLeave
		}
		if err := s.checkObligations(ctx, groupID, m.ID); err != nil {
			return err
		}
		if req, err = s.leaves.Review(ctx, requestID, model.LeaveRequestStatusApproved, userID, now); err != nil {
			return err
		}
		return deactivateMember(ctx, s.members, s.leaves, s.transfers, s.activity, groupID, userID, m, model.MemberStatusLeft, model.ActionMemberLeft, now)
	})
	if err != nil {
		return LeaveRequest{}, err
	}
	return s.view(ctx, req)
}

// Reject keeps the member in the group. The reason, if any, goes to the
// activity log.
func (s *LeaveService) Reject(ctx context.Context, groupID, userID, requestID uuid.UUID, reason *string) (LeaveRequest, error) {
	now := s.clock.Now()
	var req model.LeaveRequest
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		if req, err = s.pending(ctx, groupID, requestID, me); err != nil {
			return err
		}
		if req, err = s.leaves.Review(ctx, requestID, model.LeaveRequestStatusRejected, userID, now); err != nil {
			return err
		}
		var after map[string]any
		if reason != nil && strings.TrimSpace(*reason) != "" {
			after = map[string]any{"reason": strings.TrimSpace(*reason)}
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionMemberLeaveRejected,
			EntityType: model.EntityTypeMember, EntityID: req.MemberID, After: after,
		})
	})
	if err != nil {
		return LeaveRequest{}, err
	}
	return s.view(ctx, req)
}

// pending row-locks a pending request that reviewer may decide on; nobody
// decides on their own request.
func (s *LeaveService) pending(ctx context.Context, groupID, requestID uuid.UUID, reviewer model.GroupMember) (model.LeaveRequest, error) {
	req, err := s.leaves.GetForUpdate(ctx, groupID, requestID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.LeaveRequest{}, errLeaveRequestNotFound
	}
	if err != nil {
		return model.LeaveRequest{}, err
	}
	if !req.IsPending() {
		return model.LeaveRequest{}, model.ErrRequestNotPending
	}
	if req.MemberID == reviewer.ID {
		return model.LeaveRequest{}, model.ErrForbiddenRole.WithDetail("Another organizer must decide on your own request.")
	}
	return req, nil
}

func (s *LeaveService) view(ctx context.Context, req model.LeaveRequest) (LeaveRequest, error) {
	v, err := s.members.GetView(ctx, req.GroupID, req.MemberID)
	if err != nil {
		return LeaveRequest{}, err
	}
	lr := LeaveRequest{Request: req}
	if lr.Member, err = s.refs.member(ctx, v, false); err != nil {
		return LeaveRequest{}, err
	}
	if req.ReviewedBy != nil {
		ref, err := s.refs.user(ctx, *req.ReviewedBy)
		if err != nil {
			return LeaveRequest{}, err
		}
		lr.ReviewedBy = &ref
	}
	return lr, nil
}
