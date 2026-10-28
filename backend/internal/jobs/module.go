package jobs

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// Module provides the Enqueuer, for both binaries.
var Module = fx.Module("jobs", fx.Provide(NewEnqueuer))

// WorkerModule runs the jobs: it builds the working River client with every
// worker and periodic job, starts it with the app and stops it gracefully.
var WorkerModule = fx.Module("jobs.worker",
	fx.Provide(
		NewPushWorker, NewRemindersWorker, NewMissedAlertWorker,
		NewExpireTransfersWorker, NewCleanupWorker, NewAccountPurgeWorker,
		NewEmailQuota, NewEmailOTPWorker, NewEmailChangedNoticeWorker, NewExpireOTPWorker,
		newClient,
	),
	fx.Invoke(func(*river.Client[pgx.Tx]) {}),
)

type clientParams struct {
	fx.In
	Lifecycle       fx.Lifecycle
	Pool            *pgxpool.Pool
	Config          *config.Config
	Clock           clock.Clock
	Log             *slog.Logger
	Push            *PushWorker
	Reminders       *RemindersWorker
	MissedAlert     *MissedAlertWorker
	ExpireTransfers *ExpireTransfersWorker
	Cleanup         *CleanupWorker
	AccountPurge    *AccountPurgeWorker
	EmailOTP        *EmailOTPWorker
	EmailNotice     *EmailChangedNoticeWorker
	ExpireOTP       *ExpireOTPWorker
}

func newClient(p clientParams) (*river.Client[pgx.Tx], error) {
	workers := river.NewWorkers()
	river.AddWorker(workers, p.Push)
	river.AddWorker(workers, p.Reminders)
	river.AddWorker(workers, p.MissedAlert)
	river.AddWorker(workers, p.ExpireTransfers)
	river.AddWorker(workers, p.Cleanup)
	river.AddWorker(workers, p.AccountPurge)
	river.AddWorker(workers, p.EmailOTP)
	river.AddWorker(workers, p.EmailNotice)
	river.AddWorker(workers, p.ExpireOTP)

	periodic, err := periodicJobs(p.Config, p.Clock)
	if err != nil {
		return nil, err
	}
	n := p.Config.Worker.MaxWorkers
	client, err := river.NewClient(riverpgxv5.New(p.Pool), &river.Config{
		Logger: p.Log,
		Queues: map[string]river.QueueConfig{
			river.QueueDefault: {MaxWorkers: max(1, n/2)},
			QueuePush:          {MaxWorkers: n},
			QueueEmail:         {MaxWorkers: max(1, n/2)},
		},
		Workers:      workers,
		PeriodicJobs: periodic,
	})
	if err != nil {
		return nil, fmt.Errorf("river client: %w", err)
	}
	p.Lifecycle.Append(fx.Hook{
		// The client outlives OnStart's deadline, so it gets its own context;
		// Stop waits for running jobs within OnStop's.
		OnStart: func(context.Context) error {
			if err := client.Start(context.Background()); err != nil {
				return fmt.Errorf("start river: %w", err)
			}
			p.Log.Info("worker started", "queues", []string{river.QueueDefault, QueuePush, QueueEmail}, "periodic_jobs", len(periodic))
			return nil
		},
		OnStop: client.Stop,
	})
	return client, nil
}

// periodicJobs schedules the daily, hourly and minutely jobs from WORKER_*_CRON in
// APP_TIMEZONE. The daily jobs carry their business date, which with their
// unique options makes a day run once even across restarts.
func periodicJobs(cfg *config.Config, clk clock.Clock) ([]*river.PeriodicJob, error) {
	loc := cfg.App.Location
	today := func() string { return dateArg(utils.Today(clk.Now(), loc)) }
	specs := []struct {
		id   string
		cron string
		args func() river.JobArgs
	}{
		{"reminders.daily", cfg.Worker.ReminderCron, func() river.JobArgs { return DailyRemindersArgs{Date: today()} }},
		{"obligations.missed_alert", cfg.Worker.MissedAlertCron, func() river.JobArgs { return MissedAlertArgs{Date: today()} }},
		{"ownership_transfers.expire", cfg.Worker.TransferExpiryCron, func() river.JobArgs { return ExpireTransfersArgs{} }},
		{"cleanup", cfg.Worker.CleanupCron, func() river.JobArgs { return CleanupArgs{} }},
		{"otp.expire", cfg.Worker.OTPExpireCron, func() river.JobArgs { return ExpireOTPArgs{} }},
	}
	out := make([]*river.PeriodicJob, len(specs))
	for i, s := range specs {
		schedule, err := NewSchedule(s.cron, loc)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", s.id, err)
		}
		args := s.args
		out[i] = river.NewPeriodicJob(schedule, func() (river.JobArgs, *river.InsertOpts) { return args(), nil },
			&river.PeriodicJobOpts{ID: s.id})
	}
	return out, nil
}
