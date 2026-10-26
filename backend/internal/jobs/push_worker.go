package jobs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// PushWorker sends a notification to every signed-in device of one user
// (push.send). It honours the user's settings at send time, renders the
// text in their language and drops tokens FCM reports dead.
type PushWorker struct {
	river.WorkerDefaults[PushArgs]
	users    *repository.UserRepository
	sessions *repository.SessionRepository
	sender   firebase.Sender
	clock    clock.Clock
	log      *slog.Logger
}

func NewPushWorker(users *repository.UserRepository, sessions *repository.SessionRepository, sender firebase.Sender, clk clock.Clock, log *slog.Logger) *PushWorker {
	return &PushWorker{users: users, sessions: sessions, sender: sender, clock: clk, log: log}
}

// Work returns an error, so River retries with backoff, only when no device
// got the push and at least one failure may pass. Delivering to some
// devices and not others is done: a retry would repeat the push on the rest.
func (w *PushWorker) Work(ctx context.Context, job *river.Job[PushArgs]) error {
	a := job.Args
	if _, err := w.users.GetByID(ctx, a.UserID); errors.Is(err, repository.ErrNotFound) {
		return nil // deleted since the push was queued
	} else if err != nil {
		return err
	}
	settings, err := w.users.GetSettings(ctx, a.UserID)
	if errors.Is(err, repository.ErrNotFound) {
		settings = model.NewUserSettings(a.UserID)
	} else if err != nil {
		return err
	}
	if !a.Notification.Allowed(settings) {
		return nil
	}
	tokens, err := w.sessions.ListPushTokens(ctx, a.UserID, w.clock.Now())
	if err != nil || len(tokens) == 0 {
		return err
	}
	title, body, err := notify.Render(a.Notification, settings.Language, a.Params)
	if err != nil {
		return river.JobCancel(err)
	}

	results, err := w.sender.Send(ctx, tokens, firebase.Message{Title: title, Body: body, Data: a.Data})
	if err != nil {
		return err
	}
	var dead []string
	delivered, retry := 0, false
	for _, r := range results {
		switch {
		case r.Err == nil:
			delivered++
		case r.Dead:
			dead = append(dead, r.Token)
		default:
			retry = retry || r.Transient
			w.log.WarnContext(ctx, "push not delivered", "user_id", a.UserID, "kind", a.Notification, "error", r.Err)
		}
	}
	if n, err := w.sessions.ClearPushTokens(ctx, dead); err != nil {
		return err
	} else if n > 0 {
		w.log.InfoContext(ctx, "dropped dead push tokens", "user_id", a.UserID, "count", len(dead))
	}
	if delivered == 0 && retry {
		return fmt.Errorf("push %s to user %s: no device reached", a.Notification, a.UserID)
	}
	return nil
}
