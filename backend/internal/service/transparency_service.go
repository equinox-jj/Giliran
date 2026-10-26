package service

import (
	"cmp"
	"context"
	"encoding/base64"
	"slices"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// Activity log page sizes (listActivity's limit parameter).
const (
	DefaultActivityLimit = 30
	MaxActivityLimit     = 100
)

// ActivityEntry is one activity log entry as members see it. Actor is nil
// for system entries; Subject is the member the entry is about, when there
// is one.
type ActivityEntry struct {
	Log     model.ActivityLog
	Actor   *UserRef
	Subject *Member
}

// ActivityPage is a page of the activity log, newest first. NextCursor is
// nil on the last page.
type ActivityPage struct {
	Entries    []ActivityEntry
	NextCursor *string
}

// Obligation is what a past winner still owes (FR-TRN-03). Remaining counts
// every period after the win not yet paid, future ones included; Overdue
// only those whose due date has passed.
type Obligation struct {
	Member          Member
	WonPeriodNo     int16
	RemainingCount  int
	RemainingAmount int64
	OverdueCount    int
	OverdueAmount   int64
}

// TransparencyService serves what every member may audit: the activity log
// and past winners' obligations (features 29 and 30).
type TransparencyService struct {
	groups   *repository.GroupRepository
	logs     *repository.ActivityRepository
	payments *repository.PaymentRepository
	members  *repository.MemberRepository
	authz    *Authz
	refs     refs
	clock    clock.Clock
	loc      *time.Location
}

func NewTransparencyService(
	groups *repository.GroupRepository,
	logs *repository.ActivityRepository,
	payments *repository.PaymentRepository,
	members *repository.MemberRepository,
	users *repository.UserRepository,
	authz *Authz,
	store storage.Storage,
	clk clock.Clock,
	cfg *config.Config,
) *TransparencyService {
	return &TransparencyService{
		groups: groups, logs: logs, payments: payments, members: members, authz: authz,
		refs: refs{users: users, store: store}, clock: clk, loc: cfg.App.Location,
	}
}

// Activity returns a page of the group's log, newest first (FR-TRN-02). Any
// member may read it. cursor is the previous page's NextCursor, or empty
// for the first page; limit must be 1 to MaxActivityLimit.
func (s *TransparencyService) Activity(ctx context.Context, groupID, userID uuid.UUID, cursor string, limit int) (ActivityPage, error) {
	if limit < 1 || limit > MaxActivityLimit {
		return ActivityPage{}, model.ErrInvalidPagination.WithDetail("limit must be between 1 and %d.", MaxActivityLimit)
	}
	beforeID, err := decodeCursor(cursor)
	if err != nil {
		return ActivityPage{}, err
	}
	if _, err := s.authz.RequireRole(ctx, groupID, userID); err != nil {
		return ActivityPage{}, err
	}
	// One row more than the page tells whether another page follows.
	logs, err := s.logs.List(ctx, groupID, beforeID, int32(limit)+1)
	if err != nil {
		return ActivityPage{}, err
	}
	var page ActivityPage
	if len(logs) > limit {
		logs = logs[:limit]
		next := encodeCursor(logs[len(logs)-1].ID)
		page.NextCursor = &next
	}
	if page.Entries, err = s.entries(ctx, groupID, logs); err != nil {
		return ActivityPage{}, err
	}
	return page, nil
}

// entries resolves the actors and subjects of logs, loading each user and
// member once.
func (s *TransparencyService) entries(ctx context.Context, groupID uuid.UUID, logs []model.ActivityLog) ([]ActivityEntry, error) {
	subjects, err := s.subjectIDs(ctx, logs)
	if err != nil {
		return nil, err
	}
	members, err := s.memberRefs(ctx, groupID, subjects)
	if err != nil {
		return nil, err
	}
	actors := map[uuid.UUID]UserRef{}
	out := make([]ActivityEntry, len(logs))
	for i, l := range logs {
		e := ActivityEntry{Log: l}
		if l.ActorUserID != nil {
			ref, ok := actors[*l.ActorUserID]
			if !ok {
				if ref, err = s.refs.user(ctx, *l.ActorUserID); err != nil {
					return nil, err
				}
				actors[*l.ActorUserID] = ref
			}
			e.Actor = &ref
		}
		if id, ok := subjects[i]; ok {
			if m, ok := members[id]; ok {
				e.Subject = &m
			}
		}
		out[i] = e
	}
	return out, nil
}

// subjectIDs maps the index of each entry about a member, payment or payout
// to the member it concerns. Group and period entries have no subject.
func (s *TransparencyService) subjectIDs(ctx context.Context, logs []model.ActivityLog) (map[int]uuid.UUID, error) {
	var paymentIDs, payoutIDs []uuid.UUID
	for _, l := range logs {
		if l.EntityID == nil {
			continue
		}
		switch l.EntityType {
		case model.EntityTypePayment:
			paymentIDs = append(paymentIDs, *l.EntityID)
		case model.EntityTypePayout:
			payoutIDs = append(payoutIDs, *l.EntityID)
		}
	}
	payers, err := s.logs.PaymentMembers(ctx, paymentIDs)
	if err != nil {
		return nil, err
	}
	winners, err := s.logs.PayoutMembers(ctx, payoutIDs)
	if err != nil {
		return nil, err
	}
	out := map[int]uuid.UUID{}
	for i, l := range logs {
		if l.EntityID == nil {
			continue
		}
		var id uuid.UUID
		var ok bool
		switch l.EntityType {
		case model.EntityTypeMember:
			id, ok = *l.EntityID, true
		case model.EntityTypePayment:
			id, ok = payers[*l.EntityID]
		case model.EntityTypePayout:
			id, ok = winners[*l.EntityID]
		}
		if ok {
			out[i] = id
		}
	}
	return out, nil
}

// memberRefs returns the group's members among ids, former members
// included, without guest phones.
func (s *TransparencyService) memberRefs(ctx context.Context, groupID uuid.UUID, ids map[int]uuid.UUID) (map[uuid.UUID]Member, error) {
	out := map[uuid.UUID]Member{}
	if len(ids) == 0 {
		return out, nil
	}
	wanted := map[uuid.UUID]bool{}
	for _, id := range ids {
		wanted[id] = true
	}
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, err
	}
	for _, v := range views {
		if !wanted[v.Member.ID] {
			continue
		}
		if _, ok := out[v.Member.ID]; ok {
			continue
		}
		m, err := s.refs.member(ctx, v, false)
		if err != nil {
			return nil, err
		}
		out[v.Member.ID] = m
	}
	return out, nil
}

// encodeCursor makes the opaque cursor for entries older than id.
func encodeCursor(id int64) string {
	return base64.RawURLEncoding.EncodeToString([]byte(strconv.FormatInt(id, 10)))
}

// decodeCursor reverses encodeCursor; an empty cursor is the first page.
func decodeCursor(cursor string) (*int64, error) {
	if cursor == "" {
		return nil, nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return nil, model.ErrBadRequest.WithDetail("The cursor is invalid.")
	}
	id, err := strconv.ParseInt(string(b), 10, 64)
	if err != nil || id < 1 {
		return nil, model.ErrBadRequest.WithDetail("The cursor is invalid.")
	}
	return &id, nil
}

// Obligations returns one entry per past winner, most overdue first
// (FR-TRN-03). Any member may read it. Due dates before today in the
// business time zone are overdue.
func (s *TransparencyService) Obligations(ctx context.Context, groupID, userID uuid.UUID) ([]Obligation, error) {
	if _, err := s.authz.RequireRole(ctx, groupID, userID); err != nil {
		return nil, err
	}
	g, err := s.groups.GetByID(ctx, groupID)
	if err != nil {
		return nil, err
	}
	rows, err := s.payments.ListObligations(ctx, groupID, utils.Today(s.clock.Now(), s.loc))
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return []Obligation{}, nil
	}
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, err
	}
	byID := make(map[uuid.UUID]repository.MemberView, len(views))
	for _, v := range views {
		byID[v.Member.ID] = v
	}
	out := make([]Obligation, 0, len(rows))
	for _, r := range rows {
		v, ok := byID[r.MemberID]
		if !ok {
			continue
		}
		m, err := s.refs.member(ctx, v, false)
		if err != nil {
			return nil, err
		}
		share := (&model.SlotMember{SharePctBasisPoints: r.ShareBasisPoints}).ShareOf(g.Amount)
		out = append(out, Obligation{
			Member:          m,
			WonPeriodNo:     r.WonPeriodNo,
			RemainingCount:  r.UnpaidCount + r.UpcomingCount,
			RemainingAmount: r.UnpaidAmount + int64(r.UpcomingCount)*share,
			OverdueCount:    r.OverdueUnpaidCount + r.OverdueUpcomingCount,
			OverdueAmount:   r.OverdueUnpaidAmount + int64(r.OverdueUpcomingCount)*share,
		})
	}
	sortObligations(out)
	return out, nil
}

// sortObligations orders the most overdue first, then by the period won.
func sortObligations(os []Obligation) {
	slices.SortStableFunc(os, func(a, b Obligation) int {
		if c := cmp.Compare(b.OverdueAmount, a.OverdueAmount); c != 0 {
			return c
		}
		return cmp.Compare(a.WonPeriodNo, b.WonPeriodNo)
	})
}
