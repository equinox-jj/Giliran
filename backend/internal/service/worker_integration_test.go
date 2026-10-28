//go:build integration

package service

// The workers of internal/jobs run against the same fixtures as the
// services, so their integration tests live here rather than rebuilding
// groups, periods and payments in package jobs.

import (
	"context"
	"errors"
	"image/color"
	"io"
	"log/slog"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

var discardLog = slog.New(slog.NewTextHandler(io.Discard, nil))

// fakeSender records what it was asked to send and answers each token with
// results[token], or delivery when there is none.
type fakeSender struct {
	mu      sync.Mutex
	sent    []firebase.Message
	tokens  [][]string
	results map[string]firebase.SendResult
}

func (f *fakeSender) Send(_ context.Context, tokens []string, msg firebase.Message) ([]firebase.SendResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sent = append(f.sent, msg)
	f.tokens = append(f.tokens, tokens)
	out := make([]firebase.SendResult, len(tokens))
	for i, tok := range tokens {
		out[i] = firebase.SendResult{Token: tok}
		if r, ok := f.results[tok]; ok {
			out[i] = r
		}
	}
	return out, nil
}

type workerEnv struct {
	transparencyEnv
	sender    *fakeSender
	push      *jobs.PushWorker
	reminders *jobs.RemindersWorker
	missed    *jobs.MissedAlertWorker
	expire    *jobs.ExpireTransfersWorker
	cleanup   *jobs.CleanupWorker
}

func newWorkerEnv(t *testing.T) workerEnv {
	t.Helper()
	e := newTransparencyEnv(t)
	tx := repository.NewTxManager(e.pool)
	users := repository.NewUserRepository(tx)
	sessions := repository.NewSessionRepository(tx)
	payments := repository.NewPaymentRepository(tx)
	members := repository.NewMemberRepository(tx)
	cfg := &config.Config{Retention: config.Retention{
		RevokedSessions: 30 * 24 * time.Hour, PaymentProofs: 90 * 24 * time.Hour, OTPRequests: 24 * time.Hour,
	}}
	sender := &fakeSender{results: map[string]firebase.SendResult{}}
	return workerEnv{
		transparencyEnv: e,
		sender:          sender,
		push:            jobs.NewPushWorker(users, sessions, sender, e.clock, discardLog),
		reminders:       jobs.NewRemindersWorker(payments, e.jobs, discardLog),
		missed:          jobs.NewMissedAlertWorker(payments, members, e.jobs, discardLog),
		expire:          jobs.NewExpireTransfersWorker(repository.NewOwnershipTransferRepository(tx), e.clock, discardLog),
		cleanup: jobs.NewCleanupWorker(repository.NewIdempotencyRepository(tx), sessions, repository.NewOTPRepository(tx),
			repository.NewGroupRepository(tx), e.store, e.clock, cfg, discardLog),
	}
}

func pushJob(userID uuid.UUID, kind notify.Kind) *river.Job[jobs.PushArgs] {
	return &river.Job[jobs.PushArgs]{Args: jobs.PushArgs{
		UserID: userID, Notification: kind,
		Params: notify.Params{Group: "Arisan RT 05", PeriodNo: 1, Amount: 150_000, DueDate: "2026-11-02"},
		Data:   map[string]string{"type": string(kind)},
	}}
}

func TestPushWorkerSendsInUserLanguage(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	userID := env.user(t, "budi")
	env.device(t, userID)
	env.exec(t, "UPDATE user_settings SET language = 'en' WHERE user_id = $1", userID)

	// Act
	err := env.push.Work(context.Background(), pushJob(userID, notify.KindPaymentReminder))

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if len(env.sender.sent) != 1 || !slices.Equal(env.sender.tokens[0], []string{"fcm"}) {
		t.Fatalf("sent %v to %v", env.sender.sent, env.sender.tokens)
	}
	if m := env.sender.sent[0]; m.Title != "Arisan RT 05 payment reminder" || m.Body != "Your period 1 payment of Rp150.000 is due 2 Nov 2026." {
		t.Errorf("message %+v", m)
	}
}

func TestPushWorkerSkips(t *testing.T) {
	// Arrange
	tests := []struct {
		name    string
		prepare func(env workerEnv, userID uuid.UUID)
	}{
		{"setting off", func(env workerEnv, id uuid.UUID) {
			env.exec(t, "UPDATE user_settings SET notify_payment_reminders = false WHERE user_id = $1", id)
		}},
		{"no device", func(env workerEnv, id uuid.UUID) {
			env.exec(t, "UPDATE sessions SET fcm_token = NULL WHERE user_id = $1", id)
		}},
		{"signed out", func(env workerEnv, id uuid.UUID) {
			env.exec(t, "UPDATE sessions SET revoked_at = now(), revoked_reason = 'logout' WHERE user_id = $1", id)
		}},
		{"deleted account", func(env workerEnv, id uuid.UUID) {
			env.exec(t, "UPDATE users SET deleted_at = now(), phone = NULL WHERE id = $1", id)
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newWorkerEnv(t)
			userID := env.user(t, "budi")
			env.device(t, userID)
			tt.prepare(env, userID)

			// Act
			err := env.push.Work(context.Background(), pushJob(userID, notify.KindPaymentReminder))

			// Assert
			if err != nil {
				t.Fatalf("Work: %v", err)
			}
			if len(env.sender.sent) != 0 {
				t.Errorf("sent %v", env.sender.sent)
			}
		})
	}
}

func TestPushWorkerDropsDeadTokens(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	userID := env.user(t, "budi")
	env.device(t, userID)
	env.sender.results["fcm"] = firebase.SendResult{Token: "fcm", Err: errors.New("unregistered"), Dead: true}

	// Act
	err := env.push.Work(context.Background(), pushJob(userID, notify.KindDrawCompleted))

	// Assert
	if err != nil {
		t.Fatalf("Work: %v, want no retry for a dead token", err)
	}
	if n := env.count(t, "SELECT count(*) FROM sessions WHERE user_id = $1 AND fcm_token IS NOT NULL", userID); n != 0 {
		t.Errorf("%d sessions keep the dead token", n)
	}
}

func TestPushWorkerRetriesWhenNothingDelivered(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	userID := env.user(t, "budi")
	env.device(t, userID)
	env.sender.results["fcm"] = firebase.SendResult{Token: "fcm", Err: errors.New("unavailable"), Transient: true}

	// Act
	err := env.push.Work(context.Background(), pushJob(userID, notify.KindDrawCompleted))

	// Assert
	if err == nil {
		t.Error("got nil, want an error so River retries")
	}
	if n := env.count(t, "SELECT count(*) FROM sessions WHERE user_id = $1 AND fcm_token = 'fcm'", userID); n != 1 {
		t.Errorf("transient failure dropped the token")
	}
}

func TestRemindersWorkerQueuesDuePayments(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	a, period, pay := env.started(t)
	if _, err := env.payments.MarkPaid(context.Background(), a.groupID, pay["rina"], a.rina, model.PaymentMethodCash, nil); err != nil {
		t.Fatalf("MarkPaid: %v", err)
	}
	env.exec(t, "UPDATE user_settings SET notify_payment_reminders = false WHERE user_id = $1", a.sari)
	tests := []struct {
		name string
		date time.Time
		want []uuid.UUID
	}{
		{"two days before", period.DueDate.AddDate(0, 0, -2), []uuid.UUID{a.budi}},
		{"on the due date", period.DueDate, []uuid.UUID{a.budi}},
		{"other days", period.DueDate.AddDate(0, 0, -1), nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			env.exec(t, "DELETE FROM river_job")

			// Act
			err := env.reminders.Work(context.Background(),
				&river.Job[jobs.DailyRemindersArgs]{Args: jobs.DailyRemindersArgs{Date: tt.date.Format(time.DateOnly)}})

			// Assert
			if err != nil {
				t.Fatalf("Work: %v", err)
			}
			got := pushesOf(t, env.authEnv, notify.KindPaymentReminder)
			if !slices.Equal(userIDs(got), tt.want) {
				t.Errorf("reminded %v, want %v (not paid, guest or opted out)", userIDs(got), tt.want)
			}
		})
	}
}

func TestRemindersWorkerRetryDoesNotPushTwice(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	_, period, _ := env.started(t)
	job := &river.Job[jobs.DailyRemindersArgs]{Args: jobs.DailyRemindersArgs{Date: period.DueDate.Format(time.DateOnly)}}
	if err := env.reminders.Work(context.Background(), job); err != nil {
		t.Fatalf("first Work: %v", err)
	}
	first := len(pushesOf(t, env.authEnv, notify.KindPaymentReminder))

	// Act
	err := env.reminders.Work(context.Background(), job)

	// Assert
	if err != nil {
		t.Fatalf("second Work: %v", err)
	}
	if n := len(pushesOf(t, env.authEnv, notify.KindPaymentReminder)); first == 0 || n != first {
		t.Errorf("%d pushes after the retry, %d before", n, first)
	}
}

func TestMissedAlertWorkerTellsManagersAboutPastWinners(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	d := env.drawEnv
	a := d.ready(t, model.DrawMethodFixedOrder)
	d.order(t, a, "budi", "sari", "rina", "darto")
	nameUser(t, env.authEnv, a.budi, "Budi Santoso")
	periods := d.begin(t, a)
	d.run(t, a, periods[0].ID)
	if _, err := d.payouts.Record(context.Background(), a.groupID, periods[0].ID, a.rina, nil, nil); err != nil {
		t.Fatalf("Record: %v", err)
	}
	dayAfter := periods[1].DueDate.AddDate(0, 0, 1)

	// Act
	err := env.missed.Work(context.Background(),
		&river.Job[jobs.MissedAlertArgs]{Args: jobs.MissedAlertArgs{Date: dayAfter.Format(time.DateOnly)}})

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	got := pushesOf(t, env.authEnv, notify.KindMissedPayments)
	if !slices.Equal(userIDs(got), []uuid.UUID{a.rina}) {
		t.Fatalf("alerted %v, want the organizer %v", userIDs(got), a.rina)
	}
	if p := got[0].Params; p.Count != 1 || !slices.Equal(p.Names, []string{"Budi Santoso"}) || p.PeriodNo != 2 {
		t.Errorf("params %+v, want budi's period 2 payment", p)
	}
}

func TestExpireTransfersWorker(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	if _, err := env.ownership.Offer(context.Background(), a.groupID, a.rina, a.memberIDs["budi"]); err != nil {
		t.Fatalf("Offer: %v", err)
	}
	env.clock.Advance(model.OwnershipTransferTTL + time.Minute)

	// Act
	err := env.expire.Work(context.Background(), &river.Job[jobs.ExpireTransfersArgs]{})

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if n := env.count(t, "SELECT count(*) FROM ownership_transfers WHERE group_id = $1 AND status = 'expired'", a.groupID); n != 1 {
		t.Errorf("%d expired transfers, want 1", n)
	}
}

func TestCleanupWorker(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newWorkerEnv(t)
	a, _, pay := env.started(t)
	proof, err := env.payments.UploadProof(context.Background(), a.groupID, pay["budi"], a.budi, testPNG(t, color.White))
	if err != nil {
		t.Fatalf("UploadProof: %v", err)
	}
	key := proof.CurrentProof.ObjectKey
	if _, err := env.groups.Close(context.Background(), a.groupID, a.rina); err != nil {
		t.Fatalf("Close: %v", err)
	}
	now := env.clock.Now()
	env.exec(t, "UPDATE groups SET closed_at = $2 WHERE id = $1", a.groupID, now.Add(-91*24*time.Hour))
	env.exec(t, `INSERT INTO idempotency_keys (user_id, key, method, path, request_hash, response_status, created_at, expires_at)
		VALUES ($1, 'expired-key', 'POST', '/x', 'h', 200, $2, $2), ($1, 'live-key-1', 'POST', '/x', 'h', 200, $3, $3)`,
		a.rina, now.Add(-time.Hour), now.Add(time.Hour))
	env.exec(t, "UPDATE sessions SET revoked_at = $2, revoked_reason = 'logout' WHERE user_id = $1", a.sari, now.Add(-31*24*time.Hour))
	env.exec(t, "UPDATE email_otp_requests SET created_at = $1, last_sent_at = $1, expires_at = $2", now.Add(-25*time.Hour), now.Add(-24*time.Hour))
	oldOTPs := env.count(t, "SELECT count(*) FROM email_otp_requests")
	env.exec(t, `INSERT INTO email_otp_requests (id, purpose, email, code_hash, device_platform, last_sent_at, expires_at, created_at)
		VALUES ($1, 'sign_in', 'baru@gmail.com', repeat('a', 64), 'android', $2, $3, $2)`, uuid.Must(uuid.NewV7()), now, now.Add(10*time.Minute))

	// Act
	err = env.cleanup.Work(context.Background(), &river.Job[jobs.CleanupArgs]{})

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if n := env.count(t, "SELECT count(*) FROM idempotency_keys WHERE key = 'expired-key'"); n != 0 {
		t.Error("expired idempotency key kept")
	}
	if n := env.count(t, "SELECT count(*) FROM idempotency_keys WHERE key = 'live-key-1'"); n != 1 {
		t.Error("live idempotency key deleted")
	}
	if n := env.count(t, "SELECT count(*) FROM sessions WHERE user_id = $1", a.sari); n != 0 {
		t.Error("old revoked session kept")
	}
	if n := env.count(t, "SELECT count(*) FROM sessions WHERE user_id = $1", a.budi); n == 0 {
		t.Error("active session deleted")
	}
	if n := env.count(t, "SELECT count(*) FROM email_otp_requests"); oldOTPs == 0 || n != 1 {
		t.Errorf("%d code requests left of %d old and 1 new, want only the new one", n, oldOTPs)
	}
	if _, ok := env.store.objects[key]; ok {
		t.Error("proof object kept")
	}
	if n := env.count(t, "SELECT count(*) FROM groups WHERE id = $1 AND proofs_purged_at IS NOT NULL", a.groupID); n != 1 {
		t.Error("group not marked purged")
	}
	d, err := env.payments.Get(context.Background(), a.groupID, pay["budi"], a.budi)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if d.CurrentProof != nil || len(d.Proofs) != 0 {
		t.Errorf("purged proof still offered: %+v", d.CurrentProof)
	}
}
