package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

// pushOnceADay makes a push enqueued by a daily job unique for the day, so
// a retried daily job does not push twice.
var pushOnceADay = &river.InsertOpts{
	Queue:       QueuePush,
	MaxAttempts: 5,
	UniqueOpts:  river.UniqueOpts{ByArgs: true, ByPeriod: 24 * time.Hour},
}

// RemindersWorker queues the automatic payment reminders of a day
// (reminders.daily, FR-REM-01): reminder_days_before the due date, and on
// it. Unlike a manual reminder it leaves payments.last_reminded_at alone
// and logs no activity, since no organizer acted.
type RemindersWorker struct {
	river.WorkerDefaults[DailyRemindersArgs]
	payments *repository.PaymentRepository
	enqueuer *Enqueuer
	log      *slog.Logger
}

func NewRemindersWorker(payments *repository.PaymentRepository, enqueuer *Enqueuer, log *slog.Logger) *RemindersWorker {
	return &RemindersWorker{payments: payments, enqueuer: enqueuer, log: log}
}

func (w *RemindersWorker) Work(ctx context.Context, job *river.Job[DailyRemindersArgs]) error {
	today, err := time.Parse(time.DateOnly, job.Args.Date)
	if err != nil {
		return river.JobCancel(fmt.Errorf("reminders.daily: date: %w", err))
	}
	due, err := w.payments.ListDueReminders(ctx, today)
	if err != nil {
		return err
	}
	pushes := make([]river.InsertManyParams, len(due))
	for i, d := range due {
		pushes[i] = Push(d.UserID, notify.KindPaymentReminder, notify.Params{
			Group: d.GroupName, PeriodNo: d.PeriodNo, Amount: d.Amount, DueDate: dateArg(d.DueDate),
		}, map[string]string{"group_id": d.GroupID.String(), "period_id": d.PeriodID.String(), "payment_id": d.PaymentID.String()})
		pushes[i].InsertOpts = pushOnceADay
	}
	if err := w.enqueuer.Enqueue(ctx, pushes...); err != nil {
		return err
	}
	w.log.InfoContext(ctx, "daily reminders queued", "date", job.Args.Date, "count", len(pushes))
	return nil
}

// missedNamesShown is how many names a missed-payment alert lists before
// "and N more".
const missedNamesShown = 3

// MissedAlertWorker tells organizers and co-organizers which past winners
// did not pay the period due the day before (obligations.missed_alert,
// feature 30). Looking only at yesterday's due date alerts each miss once.
type MissedAlertWorker struct {
	river.WorkerDefaults[MissedAlertArgs]
	payments *repository.PaymentRepository
	members  *repository.MemberRepository
	enqueuer *Enqueuer
	log      *slog.Logger
}

func NewMissedAlertWorker(payments *repository.PaymentRepository, members *repository.MemberRepository, enqueuer *Enqueuer, log *slog.Logger) *MissedAlertWorker {
	return &MissedAlertWorker{payments: payments, members: members, enqueuer: enqueuer, log: log}
}

func (w *MissedAlertWorker) Work(ctx context.Context, job *river.Job[MissedAlertArgs]) error {
	today, err := time.Parse(time.DateOnly, job.Args.Date)
	if err != nil {
		return river.JobCancel(fmt.Errorf("obligations.missed_alert: date: %w", err))
	}
	missed, err := w.payments.ListMissedWinnerPayments(ctx, today.AddDate(0, 0, -1))
	if err != nil {
		return err
	}
	var pushes []river.InsertManyParams
	for start := 0; start < len(missed); {
		end := start
		for end < len(missed) && missed[end].PeriodID == missed[start].PeriodID {
			end++
		}
		period := missed[start:end]
		start = end

		first := period[0]
		p := notify.Params{Group: first.GroupName, PeriodNo: first.PeriodNo, Count: len(period)}
		for _, m := range period[:min(len(period), missedNamesShown)] {
			p.Names = append(p.Names, m.MemberName)
		}
		managers, err := w.members.ListActiveUserIDs(ctx, first.GroupID, model.MemberRoleOrganizer, model.MemberRoleCoOrganizer)
		if err != nil {
			return err
		}
		for _, id := range managers {
			push := Push(id, notify.KindMissedPayments, p, map[string]string{"group_id": first.GroupID.String(), "period_id": first.PeriodID.String()})
			push.InsertOpts = pushOnceADay
			pushes = append(pushes, push)
		}
	}
	if err := w.enqueuer.Enqueue(ctx, pushes...); err != nil {
		return err
	}
	w.log.InfoContext(ctx, "missed-payment alerts queued", "date", job.Args.Date, "payments", len(missed), "pushes", len(pushes))
	return nil
}
