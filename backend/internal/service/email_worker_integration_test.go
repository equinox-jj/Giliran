//go:build integration

package service

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"

	"github.com/equinox-jj/Giliran/backend/internal/clients/email"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// fakeMailer records what it was asked to send and fails every send with err.
type fakeMailer struct {
	mu   sync.Mutex
	sent []email.Message
	err  error
}

func (f *fakeMailer) Send(_ context.Context, msg email.Message) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return "", f.err
	}
	f.sent = append(f.sent, msg)
	return "provider-id-1", nil
}

// syncBuffer is a log sink safe for the worker and the test to share.
type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

type emailEnv struct {
	authEnv
	mailer *fakeMailer
	logs   *syncBuffer
	code   *jobs.EmailOTPWorker
	notice *jobs.EmailChangedNoticeWorker
	expire *jobs.ExpireOTPWorker
}

func newEmailEnv(t *testing.T, dailyLimit int) emailEnv {
	t.Helper()
	e := newAuthEnv(t, accounts{"tok": rina})
	tx := repository.NewTxManager(e.pool)
	users := repository.NewUserRepository(tx)
	otps := repository.NewOTPRepository(tx)
	mailer := &fakeMailer{}
	logs := &syncBuffer{}
	log := slog.New(slog.NewTextHandler(logs, nil))
	cfg := &config.Config{OTP: otpCfg, SMTP: config.SMTP{DailyLimit: dailyLimit}}
	quota := jobs.NewEmailQuota(e.pool, cfg, log)
	return emailEnv{
		authEnv: e,
		mailer:  mailer,
		logs:    logs,
		code:    jobs.NewEmailOTPWorker(otps, users, mailer, quota, e.clock, cfg, log),
		notice:  jobs.NewEmailChangedNoticeWorker(users, mailer, quota, log),
		expire:  jobs.NewExpireOTPWorker(otps, e.clock, log),
	}
}

// codeJob is the email.otp job for one send of otpID, on attempt of 5.
func codeJob(otpID uuid.UUID, resendCount int16, attempt int) *river.Job[jobs.EmailOTPArgs] {
	return &river.Job[jobs.EmailOTPArgs]{
		JobRow: &rivertype.JobRow{Kind: jobs.EmailOTPArgs{}.Kind(), Attempt: attempt, MaxAttempts: 5},
		Args:   jobs.EmailOTPArgs{OTPID: otpID, ResendCount: resendCount},
	}
}

// sendStatus returns a request's send status and provider message ID.
func (e emailEnv) sendStatus(t *testing.T, id uuid.UUID) (status string, providerID *string) {
	t.Helper()
	err := e.pool.QueryRow(context.Background(),
		`SELECT send_status, provider_message_id FROM email_otp_requests WHERE id = $1`, id).Scan(&status, &providerID)
	if err != nil {
		t.Fatalf("send status: %v", err)
	}
	return status, providerID
}

func TestEmailOTPWorkerSendsCode(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newEmailEnv(t, 100)
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})

	// Act
	err := env.code.Work(context.Background(), codeJob(ch.ID, 0, 1))

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if len(env.mailer.sent) != 1 {
		t.Fatalf("%d emails sent, want 1", len(env.mailer.sent))
	}
	msg := env.mailer.sent[0]
	want := code(ch.ID, 0)
	if msg.To != rina.Email || msg.Subject != want+" adalah kode masuk Giliran" ||
		!strings.Contains(msg.Text, want) || !strings.Contains(msg.HTML, want) || !strings.Contains(msg.Text, "10 menit") {
		t.Errorf("message %+v", msg)
	}
	if status, id := env.sendStatus(t, ch.ID); status != "sent" || id == nil || *id != "provider-id-1" {
		t.Errorf("send status %s, provider id %v", status, id)
	}
	if strings.Contains(env.logs.String(), "email.quota_warning") {
		t.Error("quota warning below the threshold")
	}
}

func TestEmailOTPWorkerUsesAccountLanguage(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newEmailEnv(t, 100)
	user := env.signIn(t, "tok").Profile.User
	if _, err := env.pool.Exec(context.Background(), `UPDATE user_settings SET language = 'en' WHERE user_id = $1`, user.ID); err != nil {
		t.Fatalf("set language: %v", err)
	}
	tests := []struct {
		name    string
		purpose model.OTPPurpose
		want    string
	}{
		{"sign in, found by email", model.OTPPurposeSignIn, " is your Giliran sign-in code"},
		{"reset PIN, found by user", model.OTPPurposeResetPIN, " is your Giliran PIN reset code"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			ch := env.request(t, OTPStart{Purpose: tt.purpose, Email: rina.Email})
			before := len(env.mailer.sent)

			// Act
			err := env.code.Work(context.Background(), codeJob(ch.ID, 0, 1))

			// Assert
			if err != nil {
				t.Fatalf("Work: %v", err)
			}
			if len(env.mailer.sent) != before+1 {
				t.Fatalf("no email sent")
			}
			if got := env.mailer.sent[before].Subject; got != code(ch.ID, 0)+tt.want {
				t.Errorf("subject %q", got)
			}
		})
	}
}

func TestEmailOTPWorkerSkipsStaleJobs(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name  string
		setup func(t *testing.T, env emailEnv) (uuid.UUID, int16)
	}{
		{"resent since", func(t *testing.T, env emailEnv) (uuid.UUID, int16) {
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			env.clock.Advance(otpCfg.ResendInterval)
			if _, err := env.otp.Resend(context.Background(), ch.ID, nil); err != nil {
				t.Fatalf("Resend: %v", err)
			}
			return ch.ID, 0
		}},
		{"verified", func(t *testing.T, env emailEnv) (uuid.UUID, int16) {
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			if _, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, nil); err != nil {
				t.Fatalf("Verify: %v", err)
			}
			return ch.ID, 0
		}},
		{"cancelled by a new request", func(t *testing.T, env emailEnv) (uuid.UUID, int16) {
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			return ch.ID, 0
		}},
		{"reset PIN for an unknown email", func(t *testing.T, env emailEnv) (uuid.UUID, int16) {
			return env.request(t, OTPStart{Purpose: model.OTPPurposeResetPIN, Email: "tidakada@gmail.com"}).ID, 0
		}},
		{"deleted by cleanup", func(*testing.T, emailEnv) (uuid.UUID, int16) {
			return uuid.Must(uuid.NewV7()), 0
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newEmailEnv(t, 100)
			id, resend := tt.setup(t, env)

			// Act
			err := env.code.Work(context.Background(), codeJob(id, resend, 1))

			// Assert
			if err != nil {
				t.Errorf("Work: %v", err)
			}
			if len(env.mailer.sent) != 0 {
				t.Errorf("sent %+v", env.mailer.sent)
			}
		})
	}
}

func TestEmailOTPWorkerRetriesTemporaryFailure(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newEmailEnv(t, 100)
	env.mailer.err = errors.New("dial tcp: i/o timeout")
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})

	// Act
	err := env.code.Work(context.Background(), codeJob(ch.ID, 0, 1))

	// Assert
	var cancel *river.JobCancelError
	if err == nil || errors.As(err, &cancel) {
		t.Errorf("err %v, want a retryable error", err)
	}
	if status, _ := env.sendStatus(t, ch.ID); status != "queued" {
		t.Errorf("send status %s, want queued", status)
	}
	if strings.Contains(env.logs.String(), "email.send_failed") {
		t.Error("alerted before giving up")
	}
}

func TestEmailOTPWorkerGivesUp(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name     string
		sendErr  error
		attempt  int
		advance  time.Duration
		wantSent int
	}{
		{"permanent failure", email.Permanent(errors.New("550 no such user")), 1, 0, 0},
		{"last attempt", errors.New("dial tcp: i/o timeout"), 5, 0, 0},
		{"code expired before sending", nil, 3, otpCfg.TTL, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newEmailEnv(t, 100)
			env.mailer.err = tt.sendErr
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			env.clock.Advance(tt.advance)

			// Act
			err := env.code.Work(context.Background(), codeJob(ch.ID, 0, tt.attempt))

			// Assert
			var cancel *river.JobCancelError
			if !errors.As(err, &cancel) {
				t.Errorf("err %v, want the job cancelled", err)
			}
			if status, _ := env.sendStatus(t, ch.ID); status != "failed" {
				t.Errorf("send status %s, want failed", status)
			}
			if len(env.mailer.sent) != tt.wantSent {
				t.Errorf("%d emails sent, want %d", len(env.mailer.sent), tt.wantSent)
			}
			if logs := env.logs.String(); !strings.Contains(logs, "level=ERROR") || !strings.Contains(logs, "email.send_failed") {
				t.Errorf("no email.send_failed alert in:\n%s", logs)
			}
		})
	}
}

func TestEmailQuotaWarns(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newEmailEnv(t, 1)
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})

	// Act
	err := env.code.Work(context.Background(), codeJob(ch.ID, 0, 1))

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if logs := env.logs.String(); !strings.Contains(logs, "email.quota_warning") || !strings.Contains(logs, "daily_limit=1") {
		t.Errorf("no quota warning in:\n%s", logs)
	}
}

func TestEmailChangedNoticeWorker(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newEmailEnv(t, 100)
	user := env.signIn(t, "tok").Profile.User
	changedAt := time.Date(2026, 10, 27, 7, 30, 0, 0, time.UTC)
	job := &river.Job[jobs.EmailChangedNoticeArgs]{
		JobRow: &rivertype.JobRow{Kind: jobs.EmailChangedNoticeArgs{}.Kind(), Attempt: 1, MaxAttempts: 10},
		Args:   jobs.EmailChangedNoticeArgs{UserID: user.ID, OldEmail: "lama@gmail.com", ChangedAt: changedAt},
	}

	// Act
	err := env.notice.Work(context.Background(), job)

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if len(env.mailer.sent) != 1 {
		t.Fatalf("%d emails sent, want 1", len(env.mailer.sent))
	}
	msg := env.mailer.sent[0]
	if msg.To != "lama@gmail.com" || !strings.Contains(msg.Text, "ri•••••@gmail.com") ||
		!strings.Contains(msg.Text, "27 Oct 2026, 14:30 WIB") {
		t.Errorf("message %+v", msg)
	}
}

func TestExpireOTPWorker(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newEmailEnv(t, 100)
	old := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
	env.clock.Advance(otpCfg.TTL)
	live := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: budi.Email})

	// Act
	err := env.expire.Work(context.Background(), &river.Job[jobs.ExpireOTPArgs]{})

	// Assert
	if err != nil {
		t.Fatalf("Work: %v", err)
	}
	if status, _, _ := env.otpRow(t, old.ID); status != "expired" {
		t.Errorf("old request %s, want expired", status)
	}
	if status, _, _ := env.otpRow(t, live.ID); status != "pending" {
		t.Errorf("live request %s, want pending", status)
	}
}
