// Package jobs holds Giliran's River background jobs: their arguments, the
// Enqueuer services insert them with, and the workers cmd/worker runs.
package jobs

import (
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
)

// QueuePush is the queue for push.send, kept apart so a backlog of
// maintenance never delays a push (FR-DRW-05 wants them within a minute).
const QueuePush = "push"

// PushArgs sends one notification to every device of one user (push.send).
type PushArgs struct {
	UserID       uuid.UUID         `json:"user_id"`
	Notification notify.Kind       `json:"notification"`
	Params       notify.Params     `json:"params"`
	Data         map[string]string `json:"data,omitempty"` // for the app to route the tap
}

func (PushArgs) Kind() string { return "push.send" }

// A push older than its last retry is no longer worth sending.
func (PushArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{Queue: QueuePush, MaxAttempts: 5}
}

// Push is a push.send job for userID. data gets the kind under "type", so
// the app knows which screen to open.
func Push(userID uuid.UUID, kind notify.Kind, p notify.Params, data map[string]string) river.InsertManyParams {
	d := map[string]string{"type": string(kind)}
	for k, v := range data {
		d[k] = v
	}
	return river.InsertManyParams{Args: PushArgs{UserID: userID, Notification: kind, Params: p, Data: d}}
}

// DailyRemindersArgs pushes the automatic payment reminders due on Date
// (reminders.daily, FR-REM-01). One job per date.
type DailyRemindersArgs struct {
	Date string `json:"date"` // YYYY-MM-DD in APP_TIMEZONE
}

func (DailyRemindersArgs) Kind() string { return "reminders.daily" }

func (DailyRemindersArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// MissedAlertArgs alerts organizers about past winners who did not pay a
// period due the day before Date (obligations.missed_alert, feature 30).
type MissedAlertArgs struct {
	Date string `json:"date"` // YYYY-MM-DD in APP_TIMEZONE
}

func (MissedAlertArgs) Kind() string { return "obligations.missed_alert" }

func (MissedAlertArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{UniqueOpts: river.UniqueOpts{ByArgs: true}}
}

// ExpireTransfersArgs marks overdue ownership transfers expired
// (ownership_transfers.expire).
type ExpireTransfersArgs struct{}

func (ExpireTransfersArgs) Kind() string { return "ownership_transfers.expire" }

// CleanupArgs applies the retention rules of DB_SCHEME §10 (cleanup).
type CleanupArgs struct{}

func (CleanupArgs) Kind() string { return "cleanup" }

// AccountPurgeArgs deletes what a deleted account left outside the
// database: its avatar object and its Firebase user (account.purge).
type AccountPurgeArgs struct {
	FirebaseUID *string `json:"firebase_uid,omitempty"`
	AvatarKey   *string `json:"avatar_key,omitempty"`
}

func (AccountPurgeArgs) Kind() string { return "account.purge" }

// Both deletes are idempotent, so retrying for about a day is safe.
func (AccountPurgeArgs) InsertOpts() river.InsertOpts {
	return river.InsertOpts{MaxAttempts: 15}
}

// dateArg formats a business date for the daily jobs' arguments.
func dateArg(d time.Time) string {
	return d.Format(time.DateOnly)
}
