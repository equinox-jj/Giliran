package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/draw"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// verificationCodeAttempts bounds the retries for a free verification code;
// with 36^10 codes a single collision is already unlikely.
const verificationCodeAttempts = 5

// DrawSlot is a slot in a draw with its holder's name.
type DrawSlot struct {
	SlotID      uuid.UUID
	SlotNo      int16
	DisplayName string
}

// DrawView is a period's draw as members see it. Before the draw only the
// commitment (seed_hash) is set; after it, everything needed to recompute
// the winner.
type DrawView struct {
	Period        model.Period
	Method        model.DrawMethod
	EligibleSlots []DrawSlot
	Winner        *DrawSlot
	DrawnBy       *UserRef
	PaidCount     *int // payments paid when the draw ran
	TotalCount    *int
	VerifyURL     *string
}

// PublicDraw is a draw as anyone with its verification code sees it: names
// are masked and nothing about payments is included. The server's own
// checks are in HashMatches and WinnerMatches; clients should recompute.
type PublicDraw struct {
	GroupName           string
	PeriodNo            int16
	TotalPeriods        int16
	PeriodID            uuid.UUID
	Algorithm           string
	SeedHash            *string
	Seed                *string
	SeedHashPublishedAt *time.Time
	EligibleSlots       []DrawSlot
	Winner              DrawSlot
	DrawnAt             time.Time
	HashMatches         bool
	WinnerMatches       bool
	VerificationCode    string
}

// DrawService runs and shows period draws (features 25–27, FR-DRW).
type DrawService struct {
	tx       *repository.TxManager
	groups   *repository.GroupRepository
	periods  *repository.PeriodRepository
	payments *repository.PaymentRepository
	members  *repository.MemberRepository
	logs     *repository.ActivityRepository
	authz    *Authz
	activity *Activity
	notify   notifier
	refs     refs
	clock    clock.Clock
	loc      *time.Location
	baseURL  string
}

func NewDrawService(
	tx *repository.TxManager,
	groups *repository.GroupRepository,
	periods *repository.PeriodRepository,
	payments *repository.PaymentRepository,
	members *repository.MemberRepository,
	logs *repository.ActivityRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	enqueuer *jobs.Enqueuer,
	store storage.Storage,
	clk clock.Clock,
	cfg *config.Config,
) *DrawService {
	return &DrawService{
		tx: tx, groups: groups, periods: periods, payments: payments, members: members, logs: logs,
		authz: authz, activity: activity, notify: notifier{jobs: enqueuer, members: members}, refs: refs{users: users, store: store},
		clock: clk, loc: cfg.App.Location, baseURL: strings.TrimRight(cfg.App.PublicBaseURL, "/"),
	}
}

// Get returns the draw of a period. Any member may read it.
func (s *DrawService) Get(ctx context.Context, groupID, periodID, userID uuid.UUID) (DrawView, error) {
	if _, err := s.authz.RequireRole(ctx, groupID, userID); err != nil {
		return DrawView{}, err
	}
	g, err := s.groups.GetByID(ctx, groupID)
	if err != nil {
		return DrawView{}, err
	}
	p, err := s.periods.Get(ctx, groupID, periodID)
	if errors.Is(err, repository.ErrNotFound) {
		return DrawView{}, model.ErrPeriodNotFound
	}
	if err != nil {
		return DrawView{}, err
	}
	return s.view(ctx, g, p)
}

// Run draws the winner of an open period (FR-DRW-02..04). Organizers and
// co-organizers only, on or after the draw date in Asia/Jakarta. If not
// every payment is paid it returns payments_incomplete with the counts
// unless confirmIncomplete is set; the counts go into the activity log
// either way. A random group reveals the sealed seed and picks with
// hmac-sha256-v1 from the unwon slots; a fixed-order group takes the next
// position.
func (s *DrawService) Run(ctx context.Context, groupID, periodID, userID uuid.UUID, confirmIncomplete bool) (DrawView, error) {
	var g model.Group
	var p model.Period
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if g, _, err = s.authz.LockGroup(ctx, groupID, userID, managers...); err != nil {
			return err
		}
		if !g.IsActive() {
			return model.ErrGroupNotActive.WithDetail("The group is %s.", g.Status)
		}
		open, err := s.periods.GetForUpdate(ctx, groupID, periodID)
		if errors.Is(err, repository.ErrNotFound) {
			return model.ErrPeriodNotFound
		}
		if err != nil {
			return err
		}
		if open.IsDrawn() {
			return model.ErrDrawAlreadyDone
		}
		if !open.IsOpen() {
			return model.ErrPeriodNotOpen.WithDetail("Period %d is %s.", open.PeriodNo, open.Status)
		}
		now := s.clock.Now()
		if utils.Today(now, s.loc).Before(open.DrawDate) {
			return model.ErrDrawTooEarly.WithDetail("Period %d draws on %s.", open.PeriodNo, open.DrawDate.Format(dateLayout))
		}
		sum, err := s.payments.Summary(ctx, open.ID)
		if err != nil {
			return err
		}
		if sum.PaidCount < sum.TotalCount && !confirmIncomplete {
			return model.ErrPaymentsIncomplete.
				WithDetail("%d of %d payments are paid. Confirm to draw anyway.", sum.PaidCount, sum.TotalCount).
				WithExtensions(map[string]any{"paid_count": sum.PaidCount, "total_count": sum.TotalCount})
		}

		res, winnerNo, err := s.pick(ctx, g, open)
		if err != nil {
			return err
		}
		if res.VerificationCode, err = s.freeVerificationCode(ctx); err != nil {
			return err
		}
		res.DrawnBy, res.DrawnAt = userID, now
		if p, err = s.periods.RecordDraw(ctx, open.ID, res); err != nil {
			return err
		}
		views, err := s.members.ListViews(ctx, groupID, true)
		if err != nil {
			return err
		}
		winner := Member{MemberView: slotHolders(views)[res.WinnerSlotID]}
		// FR-DRW-05: every member, the organizer who drew included.
		if err := s.notify.toGroup(ctx, groupID, nil, notify.KindDrawCompleted,
			notify.Params{Group: g.Name, PeriodNo: p.PeriodNo, Winner: winner.DisplayName(), SlotNo: winnerNo},
			pushData(groupID, p.ID)); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionDrawCompleted,
			EntityType: model.EntityTypePeriod, EntityID: p.ID,
			Before: map[string]any{"status": open.Status},
			After: map[string]any{
				"status": p.Status, "winner_slot_id": res.WinnerSlotID, "winner_slot_no": winnerNo,
				"verification_code": res.VerificationCode,
				"paid_count":        sum.PaidCount, "total_count": sum.TotalCount, "confirm_incomplete": confirmIncomplete,
			},
		})
	})
	if err != nil {
		return DrawView{}, err
	}
	return s.view(ctx, g, p)
}

// pick chooses p's winner from the group's unwon slots, sorted by slot
// number, and returns the result to store with the winner's slot number.
func (s *DrawService) pick(ctx context.Context, g model.Group, p model.Period) (repository.DrawResult, int16, error) {
	eligible, err := s.groups.ListEligibleSlots(ctx, g.ID)
	if err != nil {
		return repository.DrawResult{}, 0, err
	}
	ids := make([]uuid.UUID, len(eligible))
	for i, sl := range eligible {
		ids[i] = sl.ID
	}
	res := repository.DrawResult{EligibleSlotIDs: ids}
	if g.UsesSeed() {
		seed, _, err := s.periods.GetSeed(ctx, p.ID)
		if err != nil {
			return repository.DrawResult{}, 0, fmt.Errorf("draw: sealed seed of period %s: %w", p.ID, err)
		}
		res.Seed = &seed
		res.WinnerSlotID, _, err = draw.Pick(seed, p.ID, ids)
		if err != nil {
			return repository.DrawResult{}, 0, err
		}
	} else {
		if res.WinnerSlotID, err = draw.NextFixed(fixedSlots(eligible)); err != nil {
			return repository.DrawResult{}, 0, err
		}
	}
	for _, sl := range eligible {
		if sl.ID == res.WinnerSlotID {
			return res, sl.SlotNo, nil
		}
	}
	return repository.DrawResult{}, 0, fmt.Errorf("draw: winner %s is not eligible", res.WinnerSlotID)
}

// fixedSlots turns unwon slots into draw.FixedSlot values. Start requires a
// position on every slot of a fixed-order group.
func fixedSlots(slots []model.Slot) []draw.FixedSlot {
	out := make([]draw.FixedSlot, 0, len(slots))
	for _, sl := range slots {
		if sl.FixedOrderPosition != nil {
			out = append(out, draw.FixedSlot{ID: sl.ID, Position: *sl.FixedOrderPosition})
		}
	}
	return out
}

// freeVerificationCode returns a verification code no period uses. It
// checks first instead of retrying on the unique index, because a unique
// violation would abort the transaction.
func (s *DrawService) freeVerificationCode(ctx context.Context) (string, error) {
	for range verificationCodeAttempts {
		code, err := security.RandomCode(model.VerificationCodeLength)
		if err != nil {
			return "", err
		}
		taken, err := s.periods.VerificationCodeExists(ctx, code)
		if err != nil {
			return "", err
		}
		if !taken {
			return code, nil
		}
	}
	return "", fmt.Errorf("draw: no free verification code after %d attempts", verificationCodeAttempts)
}

// Public returns the draw behind a Bukti Kocok verification code
// (FR-DRW-06). No account is needed, so holder names are masked. The server
// recomputes the result before returning it.
func (s *DrawService) Public(ctx context.Context, code string) (PublicDraw, error) {
	d, err := s.periods.GetByCode(ctx, code)
	if errors.Is(err, repository.ErrNotFound) {
		return PublicDraw{}, model.ErrDrawNotFound
	}
	if err != nil {
		return PublicDraw{}, err
	}
	p := d.Period
	slots, err := s.slotNames(ctx, p.GroupID, draw.MaskName)
	if err != nil {
		return PublicDraw{}, err
	}
	out := PublicDraw{
		GroupName: d.GroupName, PeriodNo: p.PeriodNo, TotalPeriods: d.TotalPeriods, PeriodID: p.ID,
		Algorithm: p.DrawAlgorithm, SeedHash: p.SeedHash, Seed: p.Seed, SeedHashPublishedAt: d.SeedHashPublishedAt,
		EligibleSlots: pickSlots(slots, p.EligibleSlotIDs), Winner: slots[*p.WinnerSlotID], DrawnAt: *p.DrawnAt,
		VerificationCode: code,
	}
	switch p.DrawAlgorithm {
	case model.DrawAlgorithmHMACSHA256V1:
		if p.Seed != nil && p.SeedHash != nil {
			v := draw.Verify(*p.Seed, *p.SeedHash, p.ID, p.EligibleSlotIDs, *p.WinnerSlotID)
			out.HashMatches, out.WinnerMatches = v.HashMatches, v.WinnerMatches
		}
	case model.DrawAlgorithmFixedOrderV1:
		// Nothing is committed, so there is no hash to break; the winner must
		// be the eligible slot with the lowest position.
		all, err := s.groups.ListSlots(ctx, p.GroupID)
		if err != nil {
			return PublicDraw{}, err
		}
		out.HashMatches = p.Seed == nil && p.SeedHash == nil
		next, err := draw.NextFixed(fixedSlots(eligibleOf(all, p.EligibleSlotIDs)))
		out.WinnerMatches = err == nil && next == *p.WinnerSlotID
	}
	return out, nil
}

func (s *DrawService) view(ctx context.Context, g model.Group, p model.Period) (DrawView, error) {
	v := DrawView{Period: p, Method: g.DrawMethod, EligibleSlots: []DrawSlot{}}
	if !p.IsDrawn() {
		return v, nil
	}
	slots, err := s.slotNames(ctx, g.ID, func(name string) string { return name })
	if err != nil {
		return DrawView{}, err
	}
	v.EligibleSlots = pickSlots(slots, p.EligibleSlotIDs)
	w := slots[*p.WinnerSlotID]
	v.Winner = &w
	by, err := s.refs.user(ctx, *p.DrawnBy)
	if err != nil {
		return DrawView{}, err
	}
	v.DrawnBy = &by
	paid, total, err := s.logs.DrawCounts(ctx, p.ID)
	switch {
	case err == nil:
		v.PaidCount, v.TotalCount = &paid, &total
	case !errors.Is(err, repository.ErrNotFound):
		return DrawView{}, err
	}
	u := s.verifyURL(*p.VerificationCode)
	v.VerifyURL = &u
	return v, nil
}

func (s *DrawService) verifyURL(code string) string {
	return s.baseURL + "/v/" + code
}

// slotNames maps every slot of the group to its number and holder's name,
// passed through name. A slot shows its active holder, or the earliest past
// holder when nobody holds it any more.
func (s *DrawService) slotNames(ctx context.Context, groupID uuid.UUID, name func(string) string) (map[uuid.UUID]DrawSlot, error) {
	slots, err := s.groups.ListSlots(ctx, groupID)
	if err != nil {
		return nil, err
	}
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, err
	}
	holders := slotHolders(views)
	out := make(map[uuid.UUID]DrawSlot, len(slots))
	for _, sl := range slots {
		d := DrawSlot{SlotID: sl.ID, SlotNo: sl.SlotNo}
		if h, ok := holders[sl.ID]; ok {
			d.DisplayName = name(Member{MemberView: h}.DisplayName())
		}
		out[sl.ID] = d
	}
	return out, nil
}

// slotHolders maps each slot to the member holding it: the active holder,
// or the earliest past one. views come ordered by slot number and join time.
func slotHolders(views []repository.MemberView) map[uuid.UUID]repository.MemberView {
	out := make(map[uuid.UUID]repository.MemberView, len(views))
	for _, v := range views {
		cur, ok := out[v.SlotID]
		if !ok || (!cur.Member.IsActive() && v.Member.IsActive()) {
			out[v.SlotID] = v
		}
	}
	return out
}

// pickSlots returns the slots of ids in their order.
func pickSlots(slots map[uuid.UUID]DrawSlot, ids []uuid.UUID) []DrawSlot {
	out := make([]DrawSlot, len(ids))
	for i, id := range ids {
		out[i] = slots[id]
		out[i].SlotID = id
	}
	return out
}

// eligibleOf returns the slots of all whose IDs are in ids.
func eligibleOf(all []model.Slot, ids []uuid.UUID) []model.Slot {
	in := make(map[uuid.UUID]bool, len(ids))
	for _, id := range ids {
		in[id] = true
	}
	var out []model.Slot
	for _, sl := range all {
		if in[sl.ID] {
			out = append(out, sl)
		}
	}
	return out
}
