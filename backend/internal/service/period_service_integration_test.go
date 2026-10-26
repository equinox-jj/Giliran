//go:build integration

package service

import (
	"bytes"
	"context"
	"encoding/hex"
	"image"
	"image/color"
	"image/png"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

type paymentEnv struct {
	groupEnv
	periods  *PeriodService
	payments *PaymentService
	idem     *IdempotencyService
}

func newPaymentEnv(t *testing.T) paymentEnv {
	t.Helper()
	g := newGroupEnv(t)
	tx := repository.NewTxManager(g.pool)
	users := repository.NewUserRepository(tx)
	groups := repository.NewGroupRepository(tx)
	members := repository.NewMemberRepository(tx)
	periods := repository.NewPeriodRepository(tx)
	payments := repository.NewPaymentRepository(tx)
	authz := NewAuthz(groups, members)
	activity := NewActivity(repository.NewActivityRepository(tx), g.clock)
	cfg := &config.Config{MinIO: config.MinIO{UploadMaxBytes: 5 << 20}}
	return paymentEnv{
		groupEnv: g,
		periods:  NewPeriodService(periods, payments, members, users, authz, g.store),
		payments: NewPaymentService(tx, groups, periods, payments, members, users, authz, activity, g.jobs, g.store, g.clock, slog.New(slog.NewTextHandler(io.Discard, nil)), cfg),
		idem:     NewIdempotencyService(tx, repository.NewIdempotencyRepository(tx), g.clock),
	}
}

// arisan is a group ready to start: Rina organizes, Budi and Sari joined,
// and Pak Darto is a guest, on four slots with a bank account.
type arisan struct {
	groupID uuid.UUID
	rina    uuid.UUID
	budi    uuid.UUID
	sari    uuid.UUID
	// memberIDs by display name.
	memberIDs map[string]uuid.UUID
}

func (e paymentEnv) ready(t *testing.T, method model.DrawMethod) arisan {
	t.Helper()
	a := arisan{rina: e.user(t, "rina"), budi: e.user(t, "budi"), sari: e.user(t, "sari"), memberIDs: map[string]uuid.UUID{}}
	d := e.create(t, a.rina, 4, method)
	a.groupID = d.Group.ID
	a.memberIDs["rina"] = d.Me.ID
	a.memberIDs["budi"] = e.join(t, a.budi, d.Invite.Code).Member.ID
	a.memberIDs["sari"] = e.join(t, a.sari, d.Invite.Code).Member.ID
	a.memberIDs["darto"] = e.guest(t, a.groupID, a.rina, "Pak Darto", nil).Member.ID
	if _, err := e.groups.SetPaymentInfo(context.Background(), a.groupID, a.rina, "BCA", "1234567890", "Rina Susanti"); err != nil {
		t.Fatalf("SetPaymentInfo: %v", err)
	}
	if method == model.DrawMethodFixedOrder {
		slots, err := e.groups.groups.ListSlots(context.Background(), a.groupID)
		if err != nil {
			t.Fatalf("ListSlots: %v", err)
		}
		order := make([]SlotPosition, len(slots))
		for i, sl := range slots {
			order[i] = SlotPosition{SlotID: sl.ID, Position: int16(len(slots) - i)}
		}
		if _, err := e.groups.SetFixedOrder(context.Background(), a.groupID, a.rina, order); err != nil {
			t.Fatalf("SetFixedOrder: %v", err)
		}
	}
	return a
}

// started is a ready random group after start, with period 1's payments by
// payer name.
func (e paymentEnv) started(t *testing.T) (arisan, model.Period, map[string]uuid.UUID) {
	t.Helper()
	a := e.ready(t, model.DrawMethodRandom)
	if _, err := e.groups.Start(context.Background(), a.groupID, a.rina); err != nil {
		t.Fatalf("Start: %v", err)
	}
	periods, err := e.periods.List(context.Background(), a.groupID, a.rina)
	if err != nil {
		t.Fatalf("List periods: %v", err)
	}
	board, _, err := e.payments.Board(context.Background(), a.groupID, periods[0].Period.ID, a.rina)
	if err != nil {
		t.Fatalf("Board: %v", err)
	}
	byName := map[string]uuid.UUID{}
	for name, id := range a.memberIDs {
		for _, p := range board {
			if p.Payment.MemberID == id {
				byName[name] = p.Payment.ID
			}
		}
	}
	return a, periods[0].Period, byName
}

func testPNG(t *testing.T, c color.Color) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, 40, 30))
	for x := range 40 {
		for y := range 30 {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}

func TestGroupStartOpensFirstPeriod(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a := env.ready(t, model.DrawMethodRandom)

	// Act
	d, err := env.groups.Start(context.Background(), a.groupID, a.rina)

	// Assert
	if err != nil || d.Group.Status != model.GroupStatusActive || d.Group.StartedAt == nil || d.CurrentPeriodID == nil {
		t.Fatalf("Start: %v, group %+v, current %v", err, d.Group, d.CurrentPeriodID)
	}
	periods, err := env.periods.List(context.Background(), a.groupID, a.budi)
	if err != nil || len(periods) != 4 {
		t.Fatalf("List: %v, %d periods", err, len(periods))
	}
	wantDue := []time.Time{start, utils.Date(2026, time.December, 1), utils.Date(2027, time.January, 1), utils.Date(2027, time.February, 1)}
	for i, p := range periods {
		if !p.Period.DueDate.Equal(wantDue[i]) || !p.Period.DrawDate.Equal(wantDue[i]) {
			t.Errorf("period %d due %v draw %v, want %v", i+1, p.Period.DueDate, p.Period.DrawDate, wantDue[i])
		}
		if i > 0 && (p.Period.Status != model.PeriodStatusUpcoming || p.Period.SeedHash != nil || p.Summary != nil) {
			t.Errorf("period %d: %+v, summary %+v", i+1, p.Period, p.Summary)
		}
	}
	first := periods[0]
	if first.Period.ID != *d.CurrentPeriodID || first.Period.Status != model.PeriodStatusOpen || first.Period.SeedHash == nil || first.Period.Seed != nil {
		t.Fatalf("period 1: %+v", first.Period)
	}
	if s := first.Summary; s == nil || s.TotalCount != 4 || s.UnpaidCount != 4 || s.ExpectedAmount != 600_000 || s.CollectedAmount != 0 {
		t.Errorf("summary %+v", first.Summary)
	}
	var sealed string
	if err := env.pool.QueryRow(context.Background(), `SELECT seed FROM period_seeds WHERE period_id = $1`, first.Period.ID).Scan(&sealed); err != nil {
		t.Fatalf("sealed seed: %v", err)
	}
	seed, _ := hex.DecodeString(sealed)
	if security.SHA256Hex(seed) != *first.Period.SeedHash {
		t.Error("seed_hash is not the SHA-256 of the sealed seed")
	}
	if acts := env.actions(t, a.groupID); acts[len(acts)-2] != "period.opened" || acts[len(acts)-1] != "group.started" {
		t.Errorf("activity %v", acts)
	}
}

func TestGroupStartFixedOrderHasNoSeed(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a := env.ready(t, model.DrawMethodFixedOrder)

	// Act
	d, err := env.groups.Start(context.Background(), a.groupID, a.rina)

	// Assert
	if err != nil {
		t.Fatalf("Start: %v", err)
	}
	p, err := env.periods.Get(context.Background(), a.groupID, *d.CurrentPeriodID, a.rina)
	if err != nil || p.Period.Status != model.PeriodStatusOpen || p.Period.SeedHash != nil {
		t.Fatalf("Get: %v, period %+v", err, p.Period)
	}
	if n := env.count(t, `SELECT count(*) FROM period_seeds`); n != 0 {
		t.Errorf("%d sealed seeds, want 0", n)
	}
}

func TestGroupStartRefuses(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		setup func(t *testing.T, env paymentEnv) (groupID, userID uuid.UUID)
		want  error
	}{
		{"slots not filled", func(t *testing.T, env paymentEnv) (uuid.UUID, uuid.UUID) {
			rinaID := env.user(t, "rina")
			d := env.create(t, rinaID, 3, model.DrawMethodRandom)
			if _, err := env.groups.SetPaymentInfo(context.Background(), d.Group.ID, rinaID, "BCA", "1234567890", "Rina"); err != nil {
				t.Fatalf("SetPaymentInfo: %v", err)
			}
			return d.Group.ID, rinaID
		}, model.ErrSlotsNotFilled},
		{"payment info missing", func(t *testing.T, env paymentEnv) (uuid.UUID, uuid.UUID) {
			rinaID := env.user(t, "rina")
			d := env.create(t, rinaID, 2, model.DrawMethodRandom)
			env.guest(t, d.Group.ID, rinaID, "Pak Darto", nil)
			return d.Group.ID, rinaID
		}, model.ErrPaymentInfoMissing},
		{"fixed order incomplete", func(t *testing.T, env paymentEnv) (uuid.UUID, uuid.UUID) {
			rinaID := env.user(t, "rina")
			d := env.create(t, rinaID, 2, model.DrawMethodFixedOrder)
			env.guest(t, d.Group.ID, rinaID, "Pak Darto", nil)
			if _, err := env.groups.SetPaymentInfo(context.Background(), d.Group.ID, rinaID, "BCA", "1234567890", "Rina"); err != nil {
				t.Fatalf("SetPaymentInfo: %v", err)
			}
			return d.Group.ID, rinaID
		}, model.ErrFixedOrderIncomplete},
		{"already started", func(t *testing.T, env paymentEnv) (uuid.UUID, uuid.UUID) {
			a := env.ready(t, model.DrawMethodRandom)
			if _, err := env.groups.Start(context.Background(), a.groupID, a.rina); err != nil {
				t.Fatalf("Start: %v", err)
			}
			return a.groupID, a.rina
		}, model.ErrGroupNotDraft},
		{"member", func(t *testing.T, env paymentEnv) (uuid.UUID, uuid.UUID) {
			a := env.ready(t, model.DrawMethodRandom)
			return a.groupID, a.budi
		}, model.ErrForbiddenRole},
		{"non-member", func(t *testing.T, env paymentEnv) (uuid.UUID, uuid.UUID) {
			rinaID := env.user(t, "rina")
			d := env.create(t, rinaID, 2, model.DrawMethodRandom)
			return d.Group.ID, env.user(t, "joko")
		}, model.ErrGroupNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			env := newPaymentEnv(t)
			groupID, userID := tt.setup(t, env)

			// Act
			_, err := env.groups.Start(context.Background(), groupID, userID)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestGroupStartRollsBackOnFailure(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 2, model.DrawMethodRandom)

	// Act
	_, err := env.groups.Start(context.Background(), d.Group.ID, rinaID)

	// Assert
	wantErr(t, err, model.ErrSlotsNotFilled)
	if n := env.count(t, `SELECT count(*) FROM periods WHERE group_id = $1`, d.Group.ID); n != 0 {
		t.Errorf("%d periods left behind", n)
	}
}

func TestPeriodGetUnknown(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, _ := env.started(t)

	// Act
	_, err := env.periods.Get(context.Background(), a.groupID, uuid.Must(uuid.NewV7()), a.budi)

	// Assert
	wantErr(t, err, model.ErrPeriodNotFound)
}

func TestPeriodListHidesGroupFromNonMembers(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, _ := env.started(t)
	joko := env.user(t, "joko")

	// Act
	_, err := env.periods.List(context.Background(), a.groupID, joko)

	// Assert
	wantErr(t, err, model.ErrGroupNotFound)
}
