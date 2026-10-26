//go:build integration

package service

import (
	"context"
	"errors"
	"image/color"
	"io"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/draw"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// afterAllDraws is past the draw date of every period of a four-slot
// monthly group starting on start.
var afterAllDraws = time.Date(2027, time.March, 1, 3, 0, 0, 0, time.UTC)

type drawEnv struct {
	paymentEnv
	draws   *DrawService
	payouts *PayoutService
}

func newDrawEnv(t *testing.T) drawEnv {
	t.Helper()
	p := newPaymentEnv(t)
	tx := repository.NewTxManager(p.pool)
	users := repository.NewUserRepository(tx)
	groups := repository.NewGroupRepository(tx)
	members := repository.NewMemberRepository(tx)
	periods := repository.NewPeriodRepository(tx)
	payments := repository.NewPaymentRepository(tx)
	logs := repository.NewActivityRepository(tx)
	authz := NewAuthz(groups, members)
	activity := NewActivity(logs, p.clock)
	cfg := &config.Config{
		App:   config.App{PublicBaseURL: "https://giliran.test/", Location: p.groups.loc},
		MinIO: config.MinIO{UploadMaxBytes: 5 << 20},
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	return drawEnv{
		paymentEnv: p,
		draws:      NewDrawService(tx, groups, periods, payments, members, logs, users, authz, activity, p.store, p.clock, cfg),
		payouts: NewPayoutService(tx, groups, periods, payments, repository.NewPayoutRepository(tx), members, users,
			authz, activity, p.store, p.clock, log, cfg),
	}
}

// begin starts a, sets the clock past every draw date and returns the
// group's periods in order.
func (e drawEnv) begin(t *testing.T, a arisan) []model.Period {
	t.Helper()
	if _, err := e.groups.Start(context.Background(), a.groupID, a.rina); err != nil {
		t.Fatalf("Start: %v", err)
	}
	e.clock.Set(afterAllDraws)
	return e.periodList(t, a)
}

func (e drawEnv) periodList(t *testing.T, a arisan) []model.Period {
	t.Helper()
	ds, err := e.periods.List(context.Background(), a.groupID, a.rina)
	if err != nil {
		t.Fatalf("List periods: %v", err)
	}
	out := make([]model.Period, len(ds))
	for i, d := range ds {
		out[i] = d.Period
	}
	return out
}

// payAll marks every payment of the period paid in cash.
func (e drawEnv) payAll(t *testing.T, a arisan, periodID uuid.UUID) {
	t.Helper()
	board, _, err := e.payments.Board(context.Background(), a.groupID, periodID, a.rina)
	if err != nil {
		t.Fatalf("Board: %v", err)
	}
	for _, p := range board {
		if _, err := e.payments.MarkPaid(context.Background(), a.groupID, p.Payment.ID, a.rina, model.PaymentMethodCash, nil); err != nil {
			t.Fatalf("MarkPaid: %v", err)
		}
	}
}

// run draws the period after paying it in full.
func (e drawEnv) run(t *testing.T, a arisan, periodID uuid.UUID) DrawView {
	t.Helper()
	e.payAll(t, a, periodID)
	v, err := e.draws.Run(context.Background(), a.groupID, periodID, a.rina, false)
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	return v
}

// order sets a fixed-order draft group's payout order by member name.
func (e drawEnv) order(t *testing.T, a arisan, names ...string) {
	t.Helper()
	ms, err := e.members.List(context.Background(), a.groupID, a.rina, false)
	if err != nil {
		t.Fatalf("List members: %v", err)
	}
	slotOf := map[uuid.UUID]uuid.UUID{}
	for _, m := range ms {
		slotOf[m.Member.ID] = m.SlotID
	}
	order := make([]SlotPosition, len(names))
	for i, n := range names {
		order[i] = SlotPosition{SlotID: slotOf[a.memberIDs[n]], Position: int16(i + 1)}
	}
	if _, err := e.groups.SetFixedOrder(context.Background(), a.groupID, a.rina, order); err != nil {
		t.Fatalf("SetFixedOrder: %v", err)
	}
}

func TestDrawRunRandomRevealsVerifiableResult(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	first := env.begin(t, a)[0]
	env.payAll(t, a, first.ID)

	// Act
	v, err := env.draws.Run(context.Background(), a.groupID, first.ID, a.rina, false)

	// Assert
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	p := v.Period
	if p.Status != model.PeriodStatusDrawn || p.Seed == nil || p.WinnerSlotID == nil || p.DrawnBy == nil || *p.DrawnBy != a.rina {
		t.Fatalf("period %+v", p)
	}
	if got := draw.Verify(*p.Seed, *p.SeedHash, p.ID, p.EligibleSlotIDs, *p.WinnerSlotID); !got.HashMatches || !got.WinnerMatches {
		t.Errorf("Verify = %+v", got)
	}
	if len(v.EligibleSlots) != 4 {
		t.Fatalf("eligible %+v", v.EligibleSlots)
	}
	for i, s := range v.EligibleSlots {
		if s.SlotNo != int16(i+1) {
			t.Errorf("eligible[%d] is slot %d, want sorted by slot_no", i, s.SlotNo)
		}
	}
	if v.Winner == nil || v.Winner.SlotID != *p.WinnerSlotID {
		t.Errorf("winner %+v", v.Winner)
	}
	code := *p.VerificationCode
	if len(code) != model.VerificationCodeLength || v.VerifyURL == nil || *v.VerifyURL != "https://giliran.test/v/"+code {
		t.Errorf("code %q, url %v", code, v.VerifyURL)
	}
	if v.PaidCount == nil || *v.PaidCount != 4 || *v.TotalCount != 4 {
		t.Errorf("counts %v/%v", v.PaidCount, v.TotalCount)
	}
	if acts := env.actions(t, a.groupID); acts[len(acts)-1] != "draw.completed" {
		t.Errorf("activity %v", acts)
	}
}

func TestDrawGetShowsOnlyCommitmentBeforeDraw(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	first := env.begin(t, a)[0]

	// Act
	v, err := env.draws.Get(context.Background(), a.groupID, first.ID, a.budi)

	// Assert
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if v.Period.SeedHash == nil || v.Winner != nil || v.DrawnBy != nil || v.VerifyURL != nil || len(v.EligibleSlots) != 0 {
		t.Errorf("view before the draw %+v", v)
	}
	if v.Period.Seed != nil {
		t.Error("seed revealed before the draw")
	}
}

func TestDrawGetByMemberAfterDraw(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	first := env.begin(t, a)[0]
	ran := env.run(t, a, first.ID)

	// Act
	v, err := env.draws.Get(context.Background(), a.groupID, first.ID, a.budi)

	// Assert
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if v.Winner == nil || v.Winner.SlotID != ran.Winner.SlotID || v.DrawnBy == nil || v.DrawnBy.ID != a.rina || v.PaidCount == nil {
		t.Errorf("view %+v", v)
	}
}

func TestDrawRunFixedOrderTakesNextPosition(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodFixedOrder)
	env.order(t, a, "sari", "darto", "rina", "budi")
	periods := env.begin(t, a)

	// Act
	v := env.run(t, a, periods[0].ID)

	// Assert
	if v.Period.DrawAlgorithm != model.DrawAlgorithmFixedOrderV1 || v.Period.Seed != nil || v.Period.SeedHash != nil {
		t.Errorf("period %+v", v.Period)
	}
	if v.Winner == nil || v.Winner.SlotNo != 3 {
		t.Errorf("winner %+v, want Sari's slot 3", v.Winner)
	}
}

func TestDrawRunRefuses(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		setup func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (periodID, userID uuid.UUID)
		want  error
	}{
		{"before the draw date", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			env.payAll(t, a, periods[0].ID)
			env.clock.Set(time.Date(2026, time.October, 31, 16, 59, 0, 0, time.UTC)) // 23:59 WIB the day before
			return periods[0].ID, a.rina
		}, model.ErrDrawTooEarly},
		{"payments incomplete", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return periods[0].ID, a.rina
		}, model.ErrPaymentsIncomplete},
		{"member", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return periods[0].ID, a.budi
		}, model.ErrForbiddenRole},
		{"non-member", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return periods[0].ID, env.user(t, "joko")
		}, model.ErrGroupNotFound},
		{"unknown period", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return uuid.Must(uuid.NewV7()), a.rina
		}, model.ErrPeriodNotFound},
		{"upcoming period", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return periods[1].ID, a.rina
		}, model.ErrPeriodNotOpen},
		{"already drawn", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			env.run(t, a, periods[0].ID)
			return periods[0].ID, a.rina
		}, model.ErrDrawAlreadyDone},
		{"closed group", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			if _, err := env.groups.Close(context.Background(), a.groupID, a.rina); err != nil {
				t.Fatalf("Close: %v", err)
			}
			return periods[0].ID, a.rina
		}, model.ErrGroupNotActive},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			env := newDrawEnv(t)
			a := env.ready(t, model.DrawMethodRandom)
			periods := env.begin(t, a)
			periodID, userID := tt.setup(t, env, a, periods)

			// Act
			_, err := env.draws.Run(context.Background(), a.groupID, periodID, userID, false)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestDrawRunPaymentsIncompleteCarriesCounts(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a, first, pay := env.started(t)
	env.clock.Set(afterAllDraws)
	if _, err := env.payments.MarkPaid(context.Background(), a.groupID, pay["budi"], a.rina, model.PaymentMethodCash, nil); err != nil {
		t.Fatalf("MarkPaid: %v", err)
	}

	// Act
	_, err := env.draws.Run(context.Background(), a.groupID, first.ID, a.rina, false)

	// Assert
	var me *model.Error
	if !errors.As(err, &me) || me.Code != model.ErrPaymentsIncomplete.Code {
		t.Fatalf("err %v, want payments_incomplete", err)
	}
	if me.Extensions["paid_count"] != 1 || me.Extensions["total_count"] != 4 {
		t.Errorf("extensions %v", me.Extensions)
	}
}

func TestDrawRunConfirmIncompleteRecordsCounts(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	first := env.begin(t, a)[0]

	// Act
	v, err := env.draws.Run(context.Background(), a.groupID, first.ID, a.rina, true)

	// Assert
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if v.PaidCount == nil || *v.PaidCount != 0 || *v.TotalCount != 4 {
		t.Errorf("counts %v/%v", v.PaidCount, v.TotalCount)
	}
	if _, after := env.lastLog(t, a.groupID); !strings.Contains(after, `"confirm_incomplete": true`) {
		t.Errorf("after %s", after)
	}
}

func TestDrawResultIsImmutable(t *testing.T) {
	// Arrange
	sets := []string{
		"winner_slot_id = NULL",
		"seed = NULL",
		"verification_code = 'AAAAAAAAAA'",
		"draw_algorithm = 'fixed-order-v1'",
		"eligible_slot_ids = '{}'",
	}

	for _, set := range sets {
		t.Run(set, func(t *testing.T) {
			t.Parallel()
			env := newDrawEnv(t)
			a := env.ready(t, model.DrawMethodRandom)
			first := env.begin(t, a)[0]
			env.run(t, a, first.ID)

			// Act
			_, err := env.pool.Exec(context.Background(), "UPDATE periods SET "+set+" WHERE id = $1", first.ID)

			// Assert
			if err == nil || !strings.Contains(err.Error(), "immutable") {
				t.Errorf("err %v, want the guard trigger to refuse", err)
			}
		})
	}
}

func TestDrawPublicVerifiesAndMasksNames(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	first := env.begin(t, a)[0]
	ran := env.run(t, a, first.ID)

	// Act
	d, err := env.draws.Public(context.Background(), *ran.Period.VerificationCode)

	// Assert
	if err != nil {
		t.Fatalf("Public: %v", err)
	}
	if !d.HashMatches || !d.WinnerMatches || d.Seed == nil || d.SeedHashPublishedAt == nil {
		t.Errorf("public draw %+v", d)
	}
	if d.GroupName != "Arisan RT 05" || d.PeriodNo != 1 || d.TotalPeriods != 4 || d.PeriodID != first.ID {
		t.Errorf("public draw %+v", d)
	}
	if d.EligibleSlots[3].DisplayName != "Pak D." {
		t.Errorf("guest shown as %q, want Pak D.", d.EligibleSlots[3].DisplayName)
	}
	if d.Winner.SlotID != ran.Winner.SlotID {
		t.Errorf("winner %+v", d.Winner)
	}
}

func TestDrawPublicFixedOrder(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodFixedOrder)
	first := env.begin(t, a)[0]
	ran := env.run(t, a, first.ID)

	// Act
	d, err := env.draws.Public(context.Background(), *ran.Period.VerificationCode)

	// Assert
	if err != nil {
		t.Fatalf("Public: %v", err)
	}
	if d.Algorithm != model.DrawAlgorithmFixedOrderV1 || !d.HashMatches || !d.WinnerMatches || d.Seed != nil {
		t.Errorf("public draw %+v", d)
	}
}

func TestDrawPublicUnknownCode(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)

	// Act
	_, err := env.draws.Public(context.Background(), "ZZZZZZZZZZ")

	// Assert
	wantErr(t, err, model.ErrDrawNotFound)
}

func TestPayoutRecordClosesPeriodAndOpensNext(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	periods := env.begin(t, a)
	ran := env.run(t, a, periods[0].ID)
	note := "  Transfer BCA  "

	// Act
	v, err := env.payouts.Record(context.Background(), a.groupID, periods[0].ID, a.rina, testPNG(t, color.White), &note)

	// Assert
	if err != nil {
		t.Fatalf("Record: %v", err)
	}
	if v.Payout.Amount != 600_000 || v.Winner.SlotID != ran.Winner.SlotID || v.ProofURL == nil || v.Payout.Note == nil || *v.Payout.Note != "Transfer BCA" {
		t.Errorf("payout %+v", v)
	}
	if v.RecordedBy.ID != a.rina {
		t.Errorf("recorded by %+v", v.RecordedBy)
	}
	now := env.periodList(t, a)
	if now[0].Status != model.PeriodStatusClosed || now[1].Status != model.PeriodStatusOpen || now[1].SeedHash == nil {
		t.Errorf("periods 1 and 2: %s, %s (hash %v)", now[0].Status, now[1].Status, now[1].SeedHash)
	}
	if n := env.count(t, `SELECT count(*) FROM payments WHERE period_id = $1`, now[1].ID); n != 4 {
		t.Errorf("period 2 has %d payments, want 4", n)
	}
	acts := env.actions(t, a.groupID)
	if got := strings.Join(acts[len(acts)-2:], ","); got != "payout.recorded,period.opened" {
		t.Errorf("activity ends %s", got)
	}
}

func TestPayoutFullCycleCompletesGroup(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	periods := env.begin(t, a)
	winners := map[uuid.UUID]bool{}

	// Act
	for _, p := range periods {
		v := env.run(t, a, p.ID)
		winners[v.Winner.SlotID] = true
		if _, err := env.payouts.Record(context.Background(), a.groupID, p.ID, a.rina, nil, nil); err != nil {
			t.Fatalf("Record period %d: %v", p.PeriodNo, err)
		}
	}

	// Assert
	if len(winners) != 4 {
		t.Errorf("%d distinct winners, want every slot once", len(winners))
	}
	g, err := env.groups.Get(context.Background(), a.groupID, a.rina)
	if err != nil || g.Group.Status != model.GroupStatusCompleted || g.Group.CompletedAt == nil {
		t.Errorf("group %v: %+v", err, g.Group)
	}
	for _, p := range env.periodList(t, a) {
		if p.Status != model.PeriodStatusClosed {
			t.Errorf("period %d is %s", p.PeriodNo, p.Status)
		}
	}
	if _, after := env.lastLog(t, a.groupID); !strings.Contains(after, `"group_status": "completed"`) {
		t.Errorf("last entry %s", after)
	}
}

func TestPayoutRecordRefuses(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		setup func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (periodID, userID uuid.UUID)
		want  error
	}{
		{"not drawn yet", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return periods[0].ID, a.rina
		}, model.ErrPeriodNotOpen},
		{"recorded twice", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			env.run(t, a, periods[0].ID)
			if _, err := env.payouts.Record(context.Background(), a.groupID, periods[0].ID, a.rina, nil, nil); err != nil {
				t.Fatalf("Record: %v", err)
			}
			return periods[0].ID, a.rina
		}, model.ErrPayoutAlreadyRecorded},
		{"member", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			env.run(t, a, periods[0].ID)
			return periods[0].ID, a.budi
		}, model.ErrForbiddenRole},
		{"unknown period", func(t *testing.T, env drawEnv, a arisan, periods []model.Period) (uuid.UUID, uuid.UUID) {
			return uuid.Must(uuid.NewV7()), a.rina
		}, model.ErrPeriodNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			env := newDrawEnv(t)
			a := env.ready(t, model.DrawMethodRandom)
			periods := env.begin(t, a)
			periodID, userID := tt.setup(t, env, a, periods)
			before := len(env.store.keys())

			// Act
			_, err := env.payouts.Record(context.Background(), a.groupID, periodID, userID, testPNG(t, color.White), nil)

			// Assert
			wantErr(t, err, tt.want)
			if after := len(env.store.keys()); after != before {
				t.Errorf("objects left behind: %d, was %d", after, before)
			}
		})
	}
}

// paidOut is a fixed-order group whose first period Budi won and whose
// payout is recorded with a proof.
func (e drawEnv) paidOut(t *testing.T) (arisan, model.Period) {
	t.Helper()
	a := e.ready(t, model.DrawMethodFixedOrder)
	e.order(t, a, "budi", "sari", "darto", "rina")
	first := e.begin(t, a)[0]
	e.run(t, a, first.ID)
	if _, err := e.payouts.Record(context.Background(), a.groupID, first.ID, a.rina, testPNG(t, color.White), nil); err != nil {
		t.Fatalf("Record: %v", err)
	}
	return a, first
}

func TestPayoutConfirmByWinner(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a, first := env.paidOut(t)

	// Act
	v, err := env.payouts.Confirm(context.Background(), a.groupID, first.ID, a.budi)

	// Assert
	if err != nil || v.Payout.ConfirmedAt == nil || v.Payout.ConfirmedBy == nil || *v.Payout.ConfirmedBy != a.budi {
		t.Fatalf("Confirm: %v, payout %+v", err, v.Payout)
	}
	if acts := env.actions(t, a.groupID); acts[len(acts)-1] != "payout.confirmed" {
		t.Errorf("activity %v", acts)
	}
}

func TestPayoutConfirmTwiceKeepsFirst(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a, first := env.paidOut(t)
	once, err := env.payouts.Confirm(context.Background(), a.groupID, first.ID, a.budi)
	if err != nil {
		t.Fatalf("Confirm: %v", err)
	}
	env.clock.Advance(time.Hour)
	logs := len(env.actions(t, a.groupID))

	// Act
	twice, err := env.payouts.Confirm(context.Background(), a.groupID, first.ID, a.budi)

	// Assert
	if err != nil || !twice.Payout.ConfirmedAt.Equal(*once.Payout.ConfirmedAt) {
		t.Fatalf("Confirm: %v, %v vs %v", err, twice.Payout.ConfirmedAt, once.Payout.ConfirmedAt)
	}
	if n := len(env.actions(t, a.groupID)); n != logs {
		t.Errorf("activity grew from %d to %d", logs, n)
	}
}

func TestPayoutConfirmRefuses(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		user func(t *testing.T, env drawEnv, a arisan) uuid.UUID
		want error
	}{
		{"organizer", func(t *testing.T, env drawEnv, a arisan) uuid.UUID { return a.rina }, model.ErrForbiddenRole},
		{"other member", func(t *testing.T, env drawEnv, a arisan) uuid.UUID { return a.sari }, model.ErrForbiddenRole},
		{"non-member", func(t *testing.T, env drawEnv, a arisan) uuid.UUID { return env.user(t, "joko") }, model.ErrGroupNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			env := newDrawEnv(t)
			a, first := env.paidOut(t)
			userID := tt.user(t, env, a)

			// Act
			_, err := env.payouts.Confirm(context.Background(), a.groupID, first.ID, userID)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestPayoutGetWithoutPayout(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	first := env.begin(t, a)[0]

	// Act
	_, err := env.payouts.Get(context.Background(), a.groupID, first.ID, a.budi)

	// Assert
	wantErr(t, err, model.ErrNotFound)
}

func TestPayoutProofVisibleToWinnerAndOrganizersOnly(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a, first := env.paidOut(t)
	tests := []struct {
		name string
		user uuid.UUID
		want bool
	}{
		{"organizer", a.rina, true},
		{"winner", a.budi, true},
		{"other member", a.sari, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			v, err := env.payouts.Get(context.Background(), a.groupID, first.ID, tt.user)

			// Assert
			if err != nil {
				t.Fatalf("Get: %v", err)
			}
			if got := v.ProofURL != nil; got != tt.want {
				t.Errorf("proof visible %v, want %v", got, tt.want)
			}
		})
	}
}

func TestPayoutConfirmAfterGroupCompleted(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodFixedOrder)
	env.order(t, a, "darto", "sari", "rina", "budi")
	periods := env.begin(t, a)
	for _, p := range periods {
		env.run(t, a, p.ID)
		if _, err := env.payouts.Record(context.Background(), a.groupID, p.ID, a.rina, nil, nil); err != nil {
			t.Fatalf("Record period %d: %v", p.PeriodNo, err)
		}
	}

	// Act
	v, err := env.payouts.Confirm(context.Background(), a.groupID, periods[3].ID, a.budi)

	// Assert
	if err != nil || v.Payout.ConfirmedAt == nil {
		t.Fatalf("Confirm: %v, payout %+v", err, v.Payout)
	}
}
