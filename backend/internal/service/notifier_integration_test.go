//go:build integration

package service

import (
	"context"
	"errors"
	"image/color"
	"slices"
	"testing"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// pushesOf returns the queued pushes of kind, sorted by user ID.
func pushesOf(t *testing.T, e authEnv, kind notify.Kind) []jobs.PushArgs {
	t.Helper()
	var out []jobs.PushArgs
	for _, p := range queuedPushes(t, e.pool) {
		if p.Notification == kind {
			out = append(out, p)
		}
	}
	slices.SortFunc(out, func(a, b jobs.PushArgs) int { return slices.Compare(a.UserID[:], b.UserID[:]) })
	return out
}

func userIDs(pushes []jobs.PushArgs) []uuid.UUID {
	out := make([]uuid.UUID, len(pushes))
	for i, p := range pushes {
		out[i] = p.UserID
	}
	return out
}

func nameUser(t *testing.T, e authEnv, userID uuid.UUID, name string) {
	t.Helper()
	if _, err := e.pool.Exec(context.Background(), "UPDATE users SET name = $2 WHERE id = $1", userID, name); err != nil {
		t.Fatalf("name user: %v", err)
	}
}

func sortedIDs(ids ...uuid.UUID) []uuid.UUID {
	slices.SortFunc(ids, func(a, b uuid.UUID) int { return slices.Compare(a[:], b[:]) })
	return ids
}

func TestUploadProofQueuesPushToManagers(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, period, pay := env.started(t)
	nameUser(t, env.authEnv, a.budi, "Budi Santoso")

	// Act
	_, err := env.payments.UploadProof(context.Background(), a.groupID, pay["budi"], a.budi, testPNG(t, color.White))

	// Assert
	if err != nil {
		t.Fatalf("UploadProof: %v", err)
	}
	got := pushesOf(t, env.authEnv, notify.KindProofUploaded)
	if !slices.Equal(userIDs(got), []uuid.UUID{a.rina}) {
		t.Fatalf("pushed to %v, want only the organizer %v", userIDs(got), a.rina)
	}
	p := got[0]
	if p.Params.Group != "Arisan RT 05" || p.Params.PeriodNo != 1 || p.Params.Member != "Budi Santoso" {
		t.Errorf("params %+v", p.Params)
	}
	if p.Data["type"] != string(notify.KindProofUploaded) || p.Data["period_id"] != period.ID.String() || p.Data["payment_id"] != pay["budi"].String() {
		t.Errorf("data %v", p.Data)
	}
}

func TestPaymentReviewQueuesPushToPayer(t *testing.T) {
	// Arrange
	tests := []struct {
		name   string
		review func(e paymentEnv, a arisan, paymentID uuid.UUID) error
		kind   notify.Kind
		reason string
	}{
		{"approve", func(e paymentEnv, a arisan, id uuid.UUID) error {
			_, err := e.payments.Approve(context.Background(), a.groupID, id, a.rina)
			return err
		}, notify.KindPaymentApproved, ""},
		{"reject", func(e paymentEnv, a arisan, id uuid.UUID) error {
			_, err := e.payments.Reject(context.Background(), a.groupID, id, a.rina, "Nominal kurang")
			return err
		}, notify.KindPaymentRejected, "Nominal kurang"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newPaymentEnv(t)
			a, _, pay := env.started(t)
			if _, err := env.payments.UploadProof(context.Background(), a.groupID, pay["budi"], a.budi, testPNG(t, color.White)); err != nil {
				t.Fatalf("UploadProof: %v", err)
			}

			// Act
			err := tt.review(env, a, pay["budi"])

			// Assert
			if err != nil {
				t.Fatalf("review: %v", err)
			}
			got := pushesOf(t, env.authEnv, tt.kind)
			if !slices.Equal(userIDs(got), []uuid.UUID{a.budi}) {
				t.Fatalf("pushed to %v, want the payer %v", userIDs(got), a.budi)
			}
			if got[0].Params.Amount != 150_000 || got[0].Params.Reason != tt.reason {
				t.Errorf("params %+v", got[0].Params)
			}
		})
	}
}

func TestMarkPaidSkipsGuestAndSelf(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)

	// Act
	for _, name := range []string{"rina", "darto", "sari"} {
		if _, err := env.payments.MarkPaid(context.Background(), a.groupID, pay[name], a.rina, model.PaymentMethodCash, nil); err != nil {
			t.Fatalf("MarkPaid %s: %v", name, err)
		}
	}

	// Assert
	if got := userIDs(pushesOf(t, env.authEnv, notify.KindPaymentMarked)); !slices.Equal(got, []uuid.UUID{a.sari}) {
		t.Errorf("pushed to %v, want only sari %v", got, a.sari)
	}
}

func TestDrawRunQueuesResultToEveryAccount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodFixedOrder)
	env.order(t, a, "sari", "budi", "rina", "darto")
	nameUser(t, env.authEnv, a.sari, "Sari Dewi")
	periods := env.begin(t, a)

	// Act
	v := env.run(t, a, periods[0].ID)

	// Assert
	got := pushesOf(t, env.authEnv, notify.KindDrawCompleted)
	if want := sortedIDs(a.rina, a.budi, a.sari); !slices.Equal(userIDs(got), want) {
		t.Fatalf("pushed to %v, want %v (no guest)", userIDs(got), want)
	}
	if p := got[0].Params; p.Winner != "Sari Dewi" || p.SlotNo != v.Winner.SlotNo || p.PeriodNo != 1 {
		t.Errorf("params %+v, winner slot %d", p, v.Winner.SlotNo)
	}
}

func TestDrawRunRefusedQueuesNothing(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodRandom)
	periods := env.begin(t, a)

	// Act
	_, err := env.draws.Run(context.Background(), a.groupID, periods[0].ID, a.rina, false)

	// Assert
	if !errors.Is(err, model.ErrPaymentsIncomplete) {
		t.Fatalf("err %v, want payments_incomplete", err)
	}
	if got := pushesOf(t, env.authEnv, notify.KindDrawCompleted); len(got) != 0 {
		t.Errorf("queued %d draw pushes for a refused draw", len(got))
	}
}

func TestPayoutRecordQueuesPushToWinner(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newDrawEnv(t)
	a := env.ready(t, model.DrawMethodFixedOrder)
	env.order(t, a, "budi", "sari", "rina", "darto")
	periods := env.begin(t, a)
	env.run(t, a, periods[0].ID)

	// Act
	_, err := env.payouts.Record(context.Background(), a.groupID, periods[0].ID, a.rina, nil, nil)

	// Assert
	if err != nil {
		t.Fatalf("Record: %v", err)
	}
	got := pushesOf(t, env.authEnv, notify.KindPayoutRecorded)
	if !slices.Equal(userIDs(got), []uuid.UUID{a.budi}) {
		t.Fatalf("pushed to %v, want the winner %v", userIDs(got), a.budi)
	}
	if got[0].Params.Amount != 600_000 || got[0].Data["payout_id"] == "" {
		t.Errorf("push %+v", got[0])
	}
}

func TestReminderSendQueuesPushPerSentPayer(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newTransparencyEnv(t)
	a, period, _ := env.started(t)
	env.device(t, a.budi)
	env.device(t, a.sari)

	// Act
	res, err := env.reminders.Send(context.Background(), a.groupID, period.ID, a.rina, nil)

	// Assert
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	got := pushesOf(t, env.authEnv, notify.KindPaymentReminder)
	if want := sortedIDs(a.budi, a.sari); res.SentCount != 2 || !slices.Equal(userIDs(got), want) {
		t.Fatalf("sent %d, pushed to %v, want %v", res.SentCount, userIDs(got), want)
	}
	if p := got[0].Params; p.Amount != 150_000 || p.DueDate != period.DueDate.Format("2006-01-02") {
		t.Errorf("params %+v", p)
	}
}
