//go:build integration

package service

import (
	"context"
	"encoding/base64"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

// testPIN passes the weak-PIN rules.
const testPIN = "258046"

type transparencyEnv struct {
	drawEnv
	transparency *TransparencyService
	reminders    *ReminderService
	account      *AccountService
	pins         *PINService
}

func newTransparencyEnv(t *testing.T) transparencyEnv {
	t.Helper()
	d := newDrawEnv(t)
	tx := repository.NewTxManager(d.pool)
	users := repository.NewUserRepository(tx)
	sessions := repository.NewSessionRepository(tx)
	groups := repository.NewGroupRepository(tx)
	members := repository.NewMemberRepository(tx)
	periods := repository.NewPeriodRepository(tx)
	payments := repository.NewPaymentRepository(tx)
	logs := repository.NewActivityRepository(tx)
	authz := NewAuthz(groups, members)
	activity := NewActivity(logs, d.clock)
	cfg := &config.Config{App: config.App{Location: d.groups.loc}}
	pins := NewPINService(tx, users, sessions, security.NewPINHasher(pinCfg), fakeVerifier{}, d.clock, pinCfg)
	return transparencyEnv{
		drawEnv:      d,
		transparency: NewTransparencyService(groups, logs, payments, members, users, authz, d.store, d.clock, cfg),
		reminders:    NewReminderService(tx, groups, periods, payments, members, users, authz, activity, d.store, d.clock),
		account: NewAccountService(pins, groups, users, sessions, members,
			repository.NewLeaveRequestRepository(tx), repository.NewOwnershipTransferRepository(tx),
			activity, d.store, d.clock, slog.New(slog.NewTextHandler(io.Discard, nil))),
		pins: pins,
	}
}

func (e transparencyEnv) exec(t *testing.T, sql string, args ...any) {
	t.Helper()
	if _, err := e.pool.Exec(context.Background(), sql, args...); err != nil {
		t.Fatalf("exec %q: %v", sql, err)
	}
}

// device gives userID's sessions a push token.
func (e transparencyEnv) device(t *testing.T, userID uuid.UUID) {
	t.Helper()
	e.exec(t, "UPDATE sessions SET fcm_token = 'fcm' WHERE user_id = $1", userID)
}

func (e transparencyEnv) setPIN(t *testing.T, userID uuid.UUID) {
	t.Helper()
	if err := e.pins.Set(context.Background(), userID, testPIN); err != nil {
		t.Fatalf("Set PIN: %v", err)
	}
}

func TestActivityPagesNewestFirst(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _, _ := env.started(t)
	total := env.count(t, "SELECT count(*) FROM activity_logs WHERE group_id = $1", a.groupID)

	// Act
	var ids []string
	var lastID int64 = 1 << 62
	cursor, pages := "", 0
	for {
		page, err := env.transparency.Activity(context.Background(), a.groupID, a.budi, cursor, 2)
		if err != nil {
			t.Fatalf("Activity: %v", err)
		}
		pages++
		for _, e := range page.Entries {
			if e.Log.ID >= lastID {
				t.Fatalf("entry %d not older than %d", e.Log.ID, lastID)
			}
			lastID = e.Log.ID
			ids = append(ids, string(e.Log.Action))
		}
		if page.NextCursor == nil {
			break
		}
		cursor = *page.NextCursor
	}

	// Assert
	if len(ids) != total || pages != (total+1)/2 {
		t.Errorf("got %d entries in %d pages, want %d", len(ids), pages, total)
	}
	if ids[len(ids)-1] != string(model.ActionGroupCreated) {
		t.Errorf("oldest entry %q, want group.created", ids[len(ids)-1])
	}
}

func TestActivitySubjectAndActor(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _, payments := env.started(t)
	if _, err := env.payments.MarkPaid(context.Background(), a.groupID, payments["budi"], a.rina, model.PaymentMethodCash, nil); err != nil {
		t.Fatalf("MarkPaid: %v", err)
	}

	// Act
	page, err := env.transparency.Activity(context.Background(), a.groupID, a.sari, "", 1)

	// Assert
	if err != nil || len(page.Entries) != 1 || page.NextCursor == nil {
		t.Fatalf("Activity: %v, page %+v", err, page)
	}
	e := page.Entries[0]
	if e.Log.Action != model.ActionPaymentMarkedPaid || e.Actor == nil || e.Actor.ID != a.rina {
		t.Errorf("entry %+v, actor %+v", e.Log, e.Actor)
	}
	if e.Subject == nil || e.Subject.Member.ID != a.memberIDs["budi"] {
		t.Errorf("subject %+v, want budi", e.Subject)
	}
}

func TestActivityRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _, _ := env.started(t)
	joko := env.user(t, "joko")
	tests := []struct {
		name   string
		user   uuid.UUID
		cursor string
		limit  int
		want   *model.Error
	}{
		{"non-member", joko, "", 30, model.ErrGroupNotFound},
		{"limit too big", a.budi, "", MaxActivityLimit + 1, model.ErrInvalidPagination},
		{"limit zero", a.budi, "", 0, model.ErrInvalidPagination},
		{"garbage cursor", a.budi, "!!!", 30, model.ErrBadRequest},
		{"non-numeric cursor", a.budi, encodeCursorText("abc"), 30, model.ErrBadRequest},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := env.transparency.Activity(context.Background(), a.groupID, tt.user, tt.cursor, tt.limit)

			// Assert
			if !errors.Is(err, tt.want) {
				t.Errorf("err %v, want %v", err, tt.want)
			}
		})
	}
}

func encodeCursorText(s string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(s))
}

func TestObligationsAfterWin(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _ := env.paidOut(t)

	// Act
	got, err := env.transparency.Obligations(context.Background(), a.groupID, a.sari)

	// Assert
	if err != nil || len(got) != 1 {
		t.Fatalf("Obligations: %v, %+v", err, got)
	}
	o := got[0]
	if o.Member.Member.ID != a.memberIDs["budi"] || o.WonPeriodNo != 1 {
		t.Errorf("obligation of %v for period %d", o.Member.Member.ID, o.WonPeriodNo)
	}
	// Periods 2–4 remain, and the clock is past every due date.
	if o.RemainingCount != 3 || o.RemainingAmount != 450_000 || o.OverdueCount != 3 || o.OverdueAmount != 450_000 {
		t.Errorf("remaining %d/%d, overdue %d/%d", o.RemainingCount, o.RemainingAmount, o.OverdueCount, o.OverdueAmount)
	}
}

func TestObligationsCountPaidPeriods(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _ := env.paidOut(t)
	second := env.periodList(t, a)[1]
	board, _, err := env.payments.Board(context.Background(), a.groupID, second.ID, a.rina)
	if err != nil {
		t.Fatalf("Board: %v", err)
	}
	for _, p := range board {
		if p.Payment.MemberID == a.memberIDs["budi"] {
			if _, err := env.payments.MarkPaid(context.Background(), a.groupID, p.Payment.ID, a.rina, model.PaymentMethodCash, nil); err != nil {
				t.Fatalf("MarkPaid: %v", err)
			}
		}
	}

	// Act
	got, err := env.transparency.Obligations(context.Background(), a.groupID, a.budi)

	// Assert
	if err != nil || len(got) != 1 || got[0].RemainingCount != 2 || got[0].RemainingAmount != 300_000 {
		t.Fatalf("Obligations: %v, %+v", err, got)
	}
}

func TestObligationsEmptyBeforeDraw(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _, _ := env.started(t)

	// Act
	got, err := env.transparency.Obligations(context.Background(), a.groupID, a.budi)

	// Assert
	if err != nil || got == nil || len(got) != 0 {
		t.Fatalf("Obligations: %v, %#v", err, got)
	}
}

func TestReminderSendSkipsAndSends(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, period, payments := env.started(t)
	env.device(t, a.budi)
	env.device(t, a.rina)
	if _, err := env.payments.MarkPaid(context.Background(), a.groupID, payments["rina"], a.rina, model.PaymentMethodCash, nil); err != nil {
		t.Fatalf("MarkPaid: %v", err)
	}

	// Act
	res, err := env.reminders.Send(context.Background(), a.groupID, period.ID, a.rina, nil)

	// Assert
	if err != nil || res.SentCount != 1 {
		t.Fatalf("Send: %v, %+v", err, res)
	}
	reasons := map[uuid.UUID]ReminderSkipReason{}
	for _, s := range res.Skipped {
		reasons[s.Member.Member.ID] = s.Reason
	}
	want := map[uuid.UUID]ReminderSkipReason{
		a.memberIDs["rina"]:  ReminderSkipAlreadyPaid,
		a.memberIDs["sari"]:  ReminderSkipNoDevice,
		a.memberIDs["darto"]: ReminderSkipGuest,
	}
	for id, r := range want {
		if reasons[id] != r {
			t.Errorf("member %v skipped for %q, want %q", id, reasons[id], r)
		}
	}
	for _, s := range res.Skipped {
		if s.Member.Member.ID == a.memberIDs["sari"] && (s.WhatsAppPhone == nil || *s.WhatsAppPhone != sari.Phone) {
			t.Errorf("sari's WhatsApp phone %v", s.WhatsAppPhone)
		}
	}
	if acts := env.actions(t, a.groupID); acts[len(acts)-1] != string(model.ActionReminderSent) {
		t.Errorf("activity %v", acts)
	}
}

func TestReminderCooldown(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, period, _ := env.started(t)
	env.device(t, a.budi)
	budiOnly := []uuid.UUID{a.memberIDs["budi"]}
	if _, err := env.reminders.Send(context.Background(), a.groupID, period.ID, a.rina, budiOnly); err != nil {
		t.Fatalf("first Send: %v", err)
	}
	tests := []struct {
		name     string
		after    time.Duration
		wantSent int
	}{
		{"within six hours", time.Hour, 0},
		{"after six hours", ReminderCooldown, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			env.clock.Advance(tt.after)

			// Act
			res, err := env.reminders.Send(context.Background(), a.groupID, period.ID, a.rina, budiOnly)

			// Assert
			if err != nil || res.SentCount != tt.wantSent {
				t.Fatalf("Send: %v, %+v", err, res)
			}
			if tt.wantSent == 0 && (len(res.Skipped) != 1 || res.Skipped[0].Reason != ReminderSkipRecentlyReminded) {
				t.Errorf("skipped %+v", res.Skipped)
			}
		})
	}
}

func TestReminderSendRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, period, _ := env.started(t)
	upcoming := env.periodList(t, a)[1]
	tests := []struct {
		name    string
		user    uuid.UUID
		period  uuid.UUID
		members []uuid.UUID
		want    *model.Error
	}{
		{"member", a.budi, period.ID, nil, model.ErrForbiddenRole},
		{"upcoming period", a.rina, upcoming.ID, nil, model.ErrPeriodNotOpen},
		{"unknown period", a.rina, uuid.Must(uuid.NewV7()), nil, model.ErrPeriodNotFound},
		{"unknown member", a.rina, period.ID, []uuid.UUID{uuid.Must(uuid.NewV7())}, model.ErrMemberNotFound},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := env.reminders.Send(context.Background(), a.groupID, tt.period, tt.user, tt.members)

			// Assert
			if !errors.Is(err, tt.want) {
				t.Errorf("err %v, want %v", err, tt.want)
			}
		})
	}
}

func TestReminderSkipsNotificationsOff(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, period, _ := env.started(t)
	env.device(t, a.sari)
	env.exec(t, "UPDATE user_settings SET notify_payment_reminders = false WHERE user_id = $1", a.sari)

	// Act
	res, err := env.reminders.Send(context.Background(), a.groupID, period.ID, a.rina, []uuid.UUID{a.memberIDs["sari"]})

	// Assert
	if err != nil || res.SentCount != 0 || len(res.Skipped) != 1 || res.Skipped[0].Reason != ReminderSkipNotificationsOff {
		t.Fatalf("Send: %v, %+v", err, res)
	}
}

func TestRecapPhonesForManagersOnly(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, period, payments := env.started(t)
	if _, err := env.payments.MarkPaid(context.Background(), a.groupID, payments["rina"], a.rina, model.PaymentMethodCash, nil); err != nil {
		t.Fatalf("MarkPaid: %v", err)
	}
	tests := []struct {
		name       string
		user       uuid.UUID
		wantPhones bool
	}{
		{"organizer", a.rina, true},
		{"member", a.budi, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			r, err := env.reminders.Recap(context.Background(), a.groupID, period.ID, tt.user)

			// Assert
			if err != nil || r.Summary.PaidCount != 1 || r.Summary.TotalCount != 4 || len(r.Unpaid) != 3 {
				t.Fatalf("Recap: %v, %+v", err, r)
			}
			for _, u := range r.Unpaid {
				hasPhone := u.WhatsAppPhone != nil
				if u.Member.Member.ID == a.memberIDs["budi"] && hasPhone != tt.wantPhones {
					t.Errorf("budi's phone %v, want shown %v", u.WhatsAppPhone, tt.wantPhones)
				}
			}
			if r.LastWinner != nil || r.Group.BankName == nil {
				t.Errorf("last winner %+v, bank %v", r.LastWinner, r.Group.BankName)
			}
		})
	}
}

func TestRecapLastWinner(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, _ := env.paidOut(t)
	second := env.periodList(t, a)[1]

	// Act
	r, err := env.reminders.Recap(context.Background(), a.groupID, second.ID, a.sari)

	// Assert
	if err != nil || r.LastWinner == nil || r.LastWinner.Member.ID != a.memberIDs["budi"] {
		t.Fatalf("Recap: %v, last winner %+v", err, r.LastWinner)
	}
}

func TestAccountDeleteFromDraftGroup(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	env.setPIN(t, a.budi)
	key := "avatars/" + a.budi.String() + "/a.jpg"
	env.exec(t, "UPDATE users SET avatar_key = $2 WHERE id = $1", a.budi, key)
	env.store.objects[key] = []byte("jpeg")

	// Act
	err := env.account.Delete(context.Background(), a.budi, testPIN)

	// Assert
	if err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if n := env.count(t, `SELECT count(*) FROM users WHERE id = $1 AND deleted_at IS NOT NULL AND phone IS NULL
		AND firebase_uid IS NULL AND avatar_key IS NULL AND pin_hash IS NULL AND name = 'Mantan anggota'`, a.budi); n != 1 {
		t.Errorf("user not anonymized")
	}
	if n := env.count(t, "SELECT count(*) FROM sessions WHERE user_id = $1 AND revoked_reason IS DISTINCT FROM 'account_deleted'", a.budi); n != 0 {
		t.Errorf("%d sessions not revoked for account_deleted", n)
	}
	if n := env.count(t, "SELECT count(*) FROM group_members WHERE id = $1 AND status = 'left'", a.memberIDs["budi"]); n != 1 {
		t.Errorf("membership still active")
	}
	if _, ok := env.store.objects[key]; ok {
		t.Errorf("avatar object kept")
	}
}

func TestAccountDeleteBlocked(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	draft := env.ready(t, model.DrawMethodRandom)
	env.setPIN(t, draft.rina)
	env.setPIN(t, draft.sari)
	if _, err := env.groups.Start(context.Background(), draft.groupID, draft.rina); err != nil {
		t.Fatalf("Start: %v", err)
	}
	tests := []struct {
		name string
		user uuid.UUID
		pin  string
		want *model.Error
	}{
		{"organizer of an active group", draft.rina, testPIN, model.ErrOrganizerCannotLeave},
		{"member of an active group", draft.sari, testPIN, model.ErrObligationsOutstanding},
		{"wrong PIN", draft.sari, "864208", model.ErrPINInvalid},
		{"no PIN", draft.budi, testPIN, model.ErrPINNotSet},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			err := env.account.Delete(context.Background(), tt.user, tt.pin)

			// Assert
			if !errors.Is(err, tt.want) {
				t.Errorf("err %v, want %v", err, tt.want)
			}
			if n := env.count(t, "SELECT count(*) FROM users WHERE id = $1 AND deleted_at IS NULL", tt.user); n != 1 {
				t.Errorf("user deleted")
			}
		})
	}
}

func TestAccountDeleteOrganizerOfDraft(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	env.setPIN(t, a.rina)

	// Act
	err := env.account.Delete(context.Background(), a.rina, testPIN)

	// Assert
	if !errors.Is(err, model.ErrOrganizerCannotLeave) {
		t.Fatalf("err %v, want organizer_cannot_leave", err)
	}
}
