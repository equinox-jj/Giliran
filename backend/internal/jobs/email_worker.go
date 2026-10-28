package jobs

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"

	"github.com/equinox-jj/Giliran/backend/internal/clients/email"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/web"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// EmailOTPWorker emails the code for one send of an email code request
// (email.otp, FR-AUTH-11). The code is derived again from OTP_SECRET, so it
// is never stored or carried in the job. A job whose request has moved on (a
// newer resend, verified, cancelled) sends nothing.
//
// Temporary failures retry with River's backoff; a permanent one, the last
// attempt or a code that expired meanwhile marks the request failed and
// logs email.send_failed at ERROR, the admin alert.
type EmailOTPWorker struct {
	river.WorkerDefaults[EmailOTPArgs]
	otps   *repository.OTPRepository
	users  *repository.UserRepository
	sender email.Sender
	quota  *EmailQuota
	clock  clock.Clock
	log    *slog.Logger
	secret []byte
}

func NewEmailOTPWorker(
	otps *repository.OTPRepository,
	users *repository.UserRepository,
	sender email.Sender,
	quota *EmailQuota,
	clk clock.Clock,
	cfg *config.Config,
	log *slog.Logger,
) *EmailOTPWorker {
	return &EmailOTPWorker{
		otps: otps, users: users, sender: sender, quota: quota, clock: clk, log: log,
		secret: []byte(cfg.OTP.Secret),
	}
}

func (w *EmailOTPWorker) Work(ctx context.Context, job *river.Job[EmailOTPArgs]) error {
	a := job.Args
	row, err := w.otps.Get(ctx, a.OTPID)
	if errors.Is(err, repository.ErrNotFound) {
		return nil // deleted by cleanup
	} else if err != nil {
		return err
	}
	if !row.IsPending() || row.ResendCount != a.ResendCount || row.SendStatus == model.OTPSendStatusSkipped {
		return nil
	}
	now := w.clock.Now()
	if row.IsExpired(now) {
		return w.fail(ctx, job.JobRow, row, errors.New("code expired before it was sent"))
	}

	lang, err := w.language(ctx, row)
	if err != nil {
		return err
	}
	msg, err := web.RenderOTP(web.OTPEmail{
		Code:     security.OTPCode(w.secret, row.ID, int(row.ResendCount)),
		Purpose:  string(row.Purpose),
		ValidFor: row.ExpiresAt.Sub(now),
		English:  lang == model.LanguageEnglish,
	})
	if err != nil {
		return river.JobCancel(err)
	}
	id, err := w.sender.Send(ctx, message(row.Email, msg))
	if err != nil {
		if gaveUp(job.JobRow, err) {
			return w.fail(ctx, job.JobRow, row, err)
		}
		w.log.WarnContext(ctx, "email not sent, will retry",
			"kind", job.Kind, "otp_id", row.ID, "attempt", job.Attempt, "error", err)
		return err
	}
	// The code is out, so a failure to record it must not send it again.
	if _, err := w.otps.MarkSent(ctx, row.ID, row.ResendCount, model.OTPSendStatusSent, &id); err != nil {
		w.log.ErrorContext(ctx, "email sent but not recorded", "otp_id", row.ID, "error", err)
	}
	w.quota.Check(ctx)
	return nil
}

// language is the language of the account the code is for: the requester
// for reset_pin and change_email, the account with this email for sign_in.
// A new user gets Indonesian.
func (w *EmailOTPWorker) language(ctx context.Context, row model.OTPRequest) (model.Language, error) {
	if row.UserID != nil {
		return userLanguage(ctx, w.users, *row.UserID)
	}
	u, err := w.users.GetByEmail(ctx, row.Email)
	if errors.Is(err, repository.ErrNotFound) {
		return model.DefaultLanguage, nil
	} else if err != nil {
		return "", err
	}
	return userLanguage(ctx, w.users, u.ID)
}

// fail records that the code could not be sent and stops retrying.
func (w *EmailOTPWorker) fail(ctx context.Context, job *rivertype.JobRow, row model.OTPRequest, cause error) error {
	if _, err := w.otps.MarkSent(ctx, row.ID, row.ResendCount, model.OTPSendStatusFailed, nil); err != nil {
		return err
	}
	w.log.ErrorContext(ctx, "email.send_failed",
		"kind", job.Kind, "otp_id", row.ID, "purpose", row.Purpose, "attempt", job.Attempt, "error", cause)
	return river.JobCancel(cause)
}

// EmailChangedNoticeWorker tells the address an account moved away from
// about the change (email.email_changed_notice, FR-AUTH-06). It is best
// effort: it retries temporary failures and logs email.send_failed when it
// gives up.
type EmailChangedNoticeWorker struct {
	river.WorkerDefaults[EmailChangedNoticeArgs]
	users  *repository.UserRepository
	sender email.Sender
	quota  *EmailQuota
	log    *slog.Logger
}

func NewEmailChangedNoticeWorker(users *repository.UserRepository, sender email.Sender, quota *EmailQuota, log *slog.Logger) *EmailChangedNoticeWorker {
	return &EmailChangedNoticeWorker{users: users, sender: sender, quota: quota, log: log}
}

// Work sends the notice even if the account was deleted since, without
// the new address.
func (w *EmailChangedNoticeWorker) Work(ctx context.Context, job *river.Job[EmailChangedNoticeArgs]) error {
	a := job.Args
	notice := web.EmailChangedEmail{ChangedAt: a.ChangedAt}
	u, err := w.users.GetByID(ctx, a.UserID)
	switch {
	case errors.Is(err, repository.ErrNotFound):
	case err != nil:
		return err
	case u.Email != nil:
		notice.NewEmailMasked = utils.MaskEmail(*u.Email)
	}
	lang, err := userLanguage(ctx, w.users, a.UserID)
	if err != nil {
		return err
	}
	notice.English = lang == model.LanguageEnglish
	msg, err := web.RenderEmailChanged(notice)
	if err != nil {
		return river.JobCancel(err)
	}
	if _, err := w.sender.Send(ctx, message(a.OldEmail, msg)); err != nil {
		if gaveUp(job.JobRow, err) {
			w.log.ErrorContext(ctx, "email.send_failed",
				"kind", job.Kind, "user_id", a.UserID, "attempt", job.Attempt, "error", err)
			return river.JobCancel(err)
		}
		return err
	}
	w.quota.Check(ctx)
	return nil
}

// userLanguage is the language in userID's settings, Indonesian when the
// account or its settings are gone.
func userLanguage(ctx context.Context, users *repository.UserRepository, userID uuid.UUID) (model.Language, error) {
	s, err := users.GetSettings(ctx, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.DefaultLanguage, nil
	} else if err != nil {
		return "", err
	}
	return s.Language, nil
}

func message(to string, e web.Email) email.Message {
	return email.Message{To: to, Subject: e.Subject, HTML: e.HTML, Text: e.Text}
}

// gaveUp reports whether a failed send should stop retrying: the failure is
// permanent or this was the job's last attempt.
func gaveUp(job *rivertype.JobRow, err error) bool {
	return email.IsPermanent(err) || job.Attempt >= job.MaxAttempts
}

// emailKinds are the jobs that send one email each.
var emailKinds = []string{EmailOTPArgs{}.Kind(), EmailChangedNoticeArgs{}.Kind()}

// quotaWarnPercent is the share of EMAIL_DAILY_LIMIT that triggers
// email.quota_warning (PRD §9).
const quotaWarnPercent = 80

// EmailQuota warns when the emails sent in the last 24 hours reach 80 % of
// EMAIL_DAILY_LIMIT, the provider's daily quota. It counts the email jobs
// River completed in that window (River keeps completed jobs for 24 hours by
// default). An email.otp job that skipped a stale code also counts, which
// errs on the side of warning early.
type EmailQuota struct {
	pool  *pgxpool.Pool
	limit int
	log   *slog.Logger
}

func NewEmailQuota(pool *pgxpool.Pool, cfg *config.Config, log *slog.Logger) *EmailQuota {
	return &EmailQuota{pool: pool, limit: cfg.SMTP.DailyLimit, log: log}
}

// Check runs after a send and logs email.quota_warning at WARN once the
// count reaches the threshold. A failed count is logged, never returned:
// the email is already out.
func (q *EmailQuota) Check(ctx context.Context) {
	var n int64
	err := q.pool.QueryRow(ctx, `SELECT count(*) FROM river_job
		WHERE kind = ANY($1) AND state = 'completed' AND finalized_at >= now() - $2::interval`,
		emailKinds, 24*time.Hour).Scan(&n)
	if err != nil {
		q.log.WarnContext(ctx, "email quota not checked", "error", err)
		return
	}
	n++ // this send, whose job completes after Work returns
	if n*100 >= int64(q.limit)*quotaWarnPercent {
		q.log.WarnContext(ctx, "email.quota_warning", "sent_24h", n, "daily_limit", q.limit)
	}
}
