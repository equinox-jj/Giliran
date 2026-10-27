//go:build integration

package repository

import (
	"context"
	"errors"
	"net/netip"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

var otpBase = time.Date(2026, 10, 27, 3, 0, 0, 0, time.UTC)

// otpEnv is an OTPRepository over a fresh database.
type otpEnv struct {
	repo  *OTPRepository
	users *UserRepository
}

func newOTPEnv(t *testing.T) otpEnv {
	t.Helper()
	tx := NewTxManager(integration.NewDB(t))
	return otpEnv{repo: NewOTPRepository(tx), users: NewUserRepository(tx)}
}

// user inserts an active user with this email.
func (e otpEnv) user(t *testing.T, email string) uuid.UUID {
	t.Helper()
	u, err := e.users.Create(context.Background(), uuid.Must(uuid.NewV7()), email, otpBase)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	return u.ID
}

// request inserts a pending request created at now that expires 10 minutes later.
func (e otpEnv) request(t *testing.T, o model.OTPRequest, now time.Time) model.OTPRequest {
	t.Helper()
	got, err := e.repo.Create(context.Background(), otpRequest(o), now)
	if err != nil {
		t.Fatalf("create otp: %v", err)
	}
	return got
}

// otpRequest fills the fields o leaves empty with a sign_in request.
func otpRequest(o model.OTPRequest) model.OTPRequest {
	if o.ID == uuid.Nil {
		o.ID = uuid.Must(uuid.NewV7())
	}
	if o.Purpose == "" {
		o.Purpose = model.OTPPurposeSignIn
	}
	if o.Email == "" {
		o.Email = "rina@example.com"
	}
	if o.CodeHash == "" {
		o.CodeHash = strings.Repeat("a", 64)
	}
	if o.SendStatus == "" {
		o.SendStatus = model.OTPSendStatusQueued
	}
	if o.DevicePlatform == "" {
		o.DevicePlatform = model.DevicePlatformAndroid
	}
	if o.ExpiresAt.IsZero() {
		o.ExpiresAt = otpBase.Add(10 * time.Minute)
	}
	return o
}

func TestOTPCreateMapsRow(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ip := netip.MustParseAddr("203.0.113.7")
	in := otpRequest(model.OTPRequest{DeviceName: new("Galaxy A54"), FCMToken: new("fcm"), RequesterIP: &ip})

	// Act
	got, err := e.repo.Create(context.Background(), in, otpBase)

	// Assert
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if got.ID != in.ID || got.Status != model.OTPStatusPending || got.Attempts != 0 || got.ResendCount != 0 ||
		!got.LastSentAt.Equal(otpBase) || !got.CreatedAt.Equal(otpBase) || !got.ExpiresAt.Equal(in.ExpiresAt) ||
		got.RequesterIP == nil || *got.RequesterIP != ip || *got.DeviceName != "Galaxy A54" || *got.FCMToken != "fcm" ||
		got.SendStatus != model.OTPSendStatusQueued || got.UserID != nil || got.ConsumedAt != nil {
		t.Errorf("got %+v", got)
	}
}

func TestOTPCreateRejectsSecondPending(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	e.request(t, model.OTPRequest{}, otpBase)

	// Act
	_, err := e.repo.Create(context.Background(), otpRequest(model.OTPRequest{}), otpBase)

	// Assert
	if !errors.Is(err, ErrDuplicate) {
		t.Errorf("got %v, want ErrDuplicate", err)
	}
}

func TestOTPCreateAfterCancelPending(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	first := e.request(t, model.OTPRequest{}, otpBase)
	e.request(t, model.OTPRequest{Purpose: model.OTPPurposeResetPIN}, otpBase) // other purpose, untouched
	n, err := e.repo.CancelPending(ctx, first.Email, model.OTPPurposeSignIn)
	if err != nil || n != 1 {
		t.Fatalf("CancelPending = %d, %v; want 1", n, err)
	}

	// Act
	_, err = e.repo.Create(ctx, otpRequest(model.OTPRequest{}), otpBase)

	// Assert
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if got, _ := e.repo.Get(ctx, first.ID); got.Status != model.OTPStatusCancelled {
		t.Errorf("first status %s, want cancelled", got.Status)
	}
}

func TestOTPCreateChecks(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	userID := e.user(t, "rina@example.com")
	tests := []struct {
		name string
		in   model.OTPRequest
		ok   bool
	}{
		{"change_email without user", model.OTPRequest{Purpose: model.OTPPurposeChangeEmail, Email: "a@example.com"}, false},
		{"change_email with user", model.OTPRequest{Purpose: model.OTPPurposeChangeEmail, Email: "b@example.com", UserID: &userID}, true},
		{"skipped reset_pin without user", model.OTPRequest{Purpose: model.OTPPurposeResetPIN, Email: "c@example.com", SendStatus: model.OTPSendStatusSkipped}, true},
		{"skipped reset_pin with user", model.OTPRequest{Purpose: model.OTPPurposeResetPIN, Email: "d@example.com", SendStatus: model.OTPSendStatusSkipped, UserID: &userID}, false},
		{"skipped sign_in", model.OTPRequest{Email: "e@example.com", SendStatus: model.OTPSendStatusSkipped}, false},
		{"uppercase email", model.OTPRequest{Email: "F@example.com"}, false},
		{"expiry not after send", model.OTPRequest{Email: "g@example.com", ExpiresAt: otpBase}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := e.repo.Create(context.Background(), otpRequest(tt.in), otpBase)

			// Assert
			if (err == nil) != tt.ok {
				t.Errorf("err = %v, want ok %v", err, tt.ok)
			}
		})
	}
}

func TestOTPRecordFailureLocksAtMax(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	o := e.request(t, model.OTPRequest{}, otpBase)
	for i := 1; i < model.OTPMaxAttempts; i++ {
		got, err := e.repo.RecordFailure(ctx, o.ID)
		if err != nil || got.Status != model.OTPStatusPending || int(got.Attempts) != i {
			t.Fatalf("failure %d: %+v, %v", i, got, err)
		}
	}

	// Act
	got, err := e.repo.RecordFailure(ctx, o.ID)

	// Assert
	if err != nil {
		t.Fatalf("RecordFailure: %v", err)
	}
	if got.Status != model.OTPStatusLocked || got.Attempts != model.OTPMaxAttempts || got.AttemptsRemaining() != 0 {
		t.Errorf("got status %s attempts %d, want locked at %d", got.Status, got.Attempts, model.OTPMaxAttempts)
	}
}

func TestOTPRecordFailureOnLockedRequest(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	o := e.request(t, model.OTPRequest{}, otpBase)
	for range model.OTPMaxAttempts {
		if _, err := e.repo.RecordFailure(ctx, o.ID); err != nil {
			t.Fatalf("RecordFailure: %v", err)
		}
	}

	// Act
	_, err := e.repo.RecordFailure(ctx, o.ID)

	// Assert
	if !errors.Is(err, ErrNotFound) {
		t.Errorf("got %v, want ErrNotFound", err)
	}
}

func TestOTPConsume(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	userID := e.user(t, "rina@example.com")
	o := e.request(t, model.OTPRequest{}, otpBase)
	at := otpBase.Add(time.Minute)

	// Act
	got, err := e.repo.Consume(context.Background(), o.ID, userID, at)

	// Assert
	if err != nil {
		t.Fatalf("Consume: %v", err)
	}
	if got.Status != model.OTPStatusConsumed || got.UserID == nil || *got.UserID != userID ||
		got.ConsumedAt == nil || !got.ConsumedAt.Equal(at) {
		t.Errorf("got %+v", got)
	}
}

func TestOTPConsumeTwice(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	userID := e.user(t, "rina@example.com")
	o := e.request(t, model.OTPRequest{}, otpBase)
	if _, err := e.repo.Consume(ctx, o.ID, userID, otpBase.Add(time.Minute)); err != nil {
		t.Fatalf("first Consume: %v", err)
	}

	// Act
	_, err := e.repo.Consume(ctx, o.ID, userID, otpBase.Add(2*time.Minute))

	// Assert
	if !errors.Is(err, ErrNotFound) {
		t.Errorf("got %v, want ErrNotFound", err)
	}
}

func TestOTPResend(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	newHash := strings.Repeat("b", 64)
	tests := []struct {
		name       string
		in         model.OTPRequest
		resends    int // done before the Act, each a minute apart
		failures   int
		sentBefore time.Duration // offset from the latest send
		wantErr    error
		wantSend   model.OTPSendStatus
	}{
		{"after interval", model.OTPRequest{Email: "a@example.com"}, 0, 2, 0, nil, model.OTPSendStatusQueued},
		{"inside interval", model.OTPRequest{Email: "b@example.com"}, 0, 0, -time.Second, ErrNotFound, ""},
		{"skipped stays skipped", model.OTPRequest{Email: "c@example.com", Purpose: model.OTPPurposeResetPIN, SendStatus: model.OTPSendStatusSkipped}, 0, 0, 0, nil, model.OTPSendStatusSkipped},
		{"resends used up", model.OTPRequest{Email: "d@example.com"}, model.OTPMaxResends, 0, 0, ErrNotFound, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			o := e.request(t, tt.in, otpBase)
			sent := otpBase
			for range tt.resends {
				sent = sent.Add(time.Minute)
				if _, err := e.repo.Resend(ctx, o.ID, newHash, sent, sent.Add(10*time.Minute), sent); err != nil {
					t.Fatalf("setup Resend: %v", err)
				}
			}
			for range tt.failures {
				if _, err := e.repo.RecordFailure(ctx, o.ID); err != nil {
					t.Fatalf("setup RecordFailure: %v", err)
				}
			}
			now := sent.Add(time.Minute)

			// Act
			got, err := e.repo.Resend(ctx, o.ID, newHash, now, now.Add(10*time.Minute), sent.Add(tt.sentBefore))

			// Assert
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if tt.wantErr != nil {
				return
			}
			if got.CodeHash != newHash || got.Attempts != 0 || got.ResendCount != 1 || got.SendStatus != tt.wantSend ||
				!got.LastSentAt.Equal(now) || !got.ExpiresAt.Equal(now.Add(10*time.Minute)) {
				t.Errorf("got %+v", got)
			}
		})
	}
}

func TestOTPMarkSent(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	tests := []struct {
		name        string
		in          model.OTPRequest
		resendCount int16
		want        bool
	}{
		{"current send", model.OTPRequest{Email: "a@example.com"}, 1, true},
		{"stale send", model.OTPRequest{Email: "b@example.com"}, 0, false},
		{"skipped request", model.OTPRequest{Email: "c@example.com", Purpose: model.OTPPurposeResetPIN, SendStatus: model.OTPSendStatusSkipped}, 1, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			o := e.request(t, tt.in, otpBase)
			at := otpBase.Add(time.Minute)
			if _, err := e.repo.Resend(ctx, o.ID, strings.Repeat("b", 64), at, at.Add(10*time.Minute), otpBase); err != nil {
				t.Fatalf("setup Resend: %v", err)
			}

			// Act
			got, err := e.repo.MarkSent(ctx, o.ID, tt.resendCount, model.OTPSendStatusSent, new("msg-1"))

			// Assert
			if err != nil || got != tt.want {
				t.Fatalf("MarkSent = %v, %v; want %v", got, err, tt.want)
			}
			stored, _ := e.repo.Get(ctx, o.ID)
			if tt.want && (stored.SendStatus != model.OTPSendStatusSent || stored.ProviderMessageID == nil || *stored.ProviderMessageID != "msg-1") {
				t.Errorf("stored %+v", stored)
			}
		})
	}
}

func TestOTPExpireDue(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	userID := e.user(t, "rina@example.com")
	due := e.request(t, model.OTPRequest{Email: "a@example.com"}, otpBase)
	live := e.request(t, model.OTPRequest{Email: "b@example.com", ExpiresAt: otpBase.Add(15 * time.Minute)}, otpBase.Add(5*time.Minute))
	used := e.request(t, model.OTPRequest{Email: "c@example.com"}, otpBase)
	if _, err := e.repo.Consume(ctx, used.ID, userID, otpBase.Add(time.Minute)); err != nil {
		t.Fatalf("Consume: %v", err)
	}

	// Act
	n, err := e.repo.ExpireDue(ctx, otpBase.Add(10*time.Minute))

	// Assert
	if err != nil || n != 1 {
		t.Fatalf("ExpireDue = %d, %v; want 1", n, err)
	}
	want := map[uuid.UUID]model.OTPStatus{due.ID: model.OTPStatusExpired, live.ID: model.OTPStatusPending, used.ID: model.OTPStatusConsumed}
	for id, status := range want {
		if got, _ := e.repo.Get(ctx, id); got.Status != status {
			t.Errorf("%s: status %s, want %s", got.Email, got.Status, status)
		}
	}
}

func TestOTPCancelPendingForUser(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	rina := e.user(t, "rina@example.com")
	budi := e.user(t, "budi@example.com")
	mine := e.request(t, model.OTPRequest{Purpose: model.OTPPurposeChangeEmail, Email: "rina2@example.com", UserID: &rina}, otpBase)
	theirs := e.request(t, model.OTPRequest{Purpose: model.OTPPurposeChangeEmail, Email: "budi2@example.com", UserID: &budi}, otpBase)

	// Act
	n, err := e.repo.CancelPendingForUser(ctx, rina)

	// Assert
	if err != nil || n != 1 {
		t.Fatalf("CancelPendingForUser = %d, %v; want 1", n, err)
	}
	if got, _ := e.repo.Get(ctx, mine.ID); got.Status != model.OTPStatusCancelled {
		t.Errorf("mine: %s, want cancelled", got.Status)
	}
	if got, _ := e.repo.Get(ctx, theirs.ID); got.Status != model.OTPStatusPending {
		t.Errorf("theirs: %s, want pending", got.Status)
	}
}

func TestOTPCountRecent(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	ip := netip.MustParseAddr("203.0.113.7")
	other := netip.MustParseAddr("198.51.100.1")
	e.request(t, model.OTPRequest{Email: "rina@example.com", RequesterIP: &ip}, otpBase.Add(-2*time.Hour)) // outside the window
	e.request(t, model.OTPRequest{Email: "rina@example.com", Purpose: model.OTPPurposeResetPIN, RequesterIP: &ip}, otpBase)
	e.request(t, model.OTPRequest{Email: "budi@example.com", RequesterIP: &ip}, otpBase)
	e.request(t, model.OTPRequest{Email: "sari@example.com", RequesterIP: &other}, otpBase)
	since := otpBase.Add(-time.Hour)

	// Act
	byEmail, errEmail := e.repo.CountRecentByEmail(ctx, "rina@example.com", since)
	byIP, errIP := e.repo.CountRecentByIP(ctx, ip, since)

	// Assert
	if errEmail != nil || byEmail != 1 {
		t.Errorf("by email = %d, %v; want 1", byEmail, errEmail)
	}
	if errIP != nil || byIP != 2 {
		t.Errorf("by IP = %d, %v; want 2", byIP, errIP)
	}
}

func TestOTPDeleteBefore(t *testing.T) {
	// Arrange
	t.Parallel()
	e := newOTPEnv(t)
	ctx := context.Background()
	old := e.request(t, model.OTPRequest{Email: "a@example.com", ExpiresAt: otpBase.Add(-14 * time.Minute)}, otpBase.Add(-25*time.Hour))
	recent := e.request(t, model.OTPRequest{Email: "b@example.com"}, otpBase)

	// Act
	n, err := e.repo.DeleteBefore(ctx, otpBase.Add(-24*time.Hour))

	// Assert
	if err != nil || n != 1 {
		t.Fatalf("DeleteBefore = %d, %v; want 1", n, err)
	}
	if _, err := e.repo.Get(ctx, old.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("old: %v, want ErrNotFound", err)
	}
	if _, err := e.repo.Get(ctx, recent.ID); err != nil {
		t.Errorf("recent: %v", err)
	}
}
