//go:build integration

package service

import (
	"context"
	"errors"
	"net/netip"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// otpRow returns a request's status, send status and attempts.
func (e authEnv) otpRow(t *testing.T, id uuid.UUID) (status, sendStatus string, attempts int) {
	t.Helper()
	err := e.pool.QueryRow(context.Background(),
		`SELECT status, send_status, attempts FROM email_otp_requests WHERE id = $1`, id).Scan(&status, &sendStatus, &attempts)
	if err != nil {
		t.Fatalf("otp row: %v", err)
	}
	return status, sendStatus, attempts
}

// pinUser signs Rina up and sets goodPIN.
func (e authEnv) pinUser(t *testing.T) SignInResult {
	t.Helper()
	res := e.signIn(t, "tok")
	if err := e.pins.Set(context.Background(), res.Profile.User.ID, goodPIN); err != nil {
		t.Fatalf("Set PIN: %v", err)
	}
	return res
}

func strp(s string) *string { return &s }

func TestOTPSignInCreatesAccount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{})
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: "  Rina@Gmail.com "})

	// Act
	res, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, nil)

	// Assert
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if ch.EmailMasked != "ri•••••@gmail.com" || ch.AttemptsRemaining != model.OTPMaxAttempts ||
		!ch.ExpiresAt.Equal(env.clock.Now().Add(otpCfg.TTL)) || !ch.ResendAvailableAt.Equal(env.clock.Now().Add(time.Minute)) {
		t.Errorf("challenge %+v", ch)
	}
	user := res.Auth.Profile.User
	if res.Purpose != model.OTPPurposeSignIn || res.User != nil || !res.Auth.IsNewUser ||
		user.Email == nil || *user.Email != rina.Email || user.EmailVerifiedAt == nil || user.HasPIN() {
		t.Errorf("result %+v, user %+v", res, user)
	}
	if n := env.count(t, `SELECT count(*) FROM user_settings WHERE user_id = $1`, user.ID); n != 1 {
		t.Errorf("%d settings rows, want 1", n)
	}
	c := env.caller(t, *res.Auth)
	if n := env.count(t, `SELECT count(*) FROM sessions WHERE id = $1 AND user_id = $2 AND device_name = $3 AND revoked_at IS NULL`,
		c.SessionID, user.ID, android.Name); n != 1 {
		t.Error("session row missing or wrong")
	}
	if res.Auth.Tokens.ExpiresIn != 15*time.Minute || res.Auth.Tokens.RefreshToken == "" {
		t.Errorf("tokens %+v", res.Auth.Tokens)
	}
	if status, _, _ := env.otpRow(t, ch.ID); status != "consumed" {
		t.Errorf("request %s, want consumed", status)
	}
	sends := queued[jobs.EmailOTPArgs](t, env.pool, jobs.EmailOTPArgs{}.Kind())
	if len(sends) != 1 || sends[0].OTPID != ch.ID || sends[0].ResendCount != 0 {
		t.Errorf("email.otp jobs %+v", sends)
	}
}

func TestOTPSignInReturningUser(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	first := env.signIn(t, "tok")

	// Act
	second := env.signIn(t, "tok")

	// Assert
	if second.IsNewUser || second.Profile.User.ID != first.Profile.User.ID {
		t.Errorf("second sign-in: new %v, user %s, want existing %s", second.IsNewUser, second.Profile.User.ID, first.Profile.User.ID)
	}
	if n := env.count(t, `SELECT count(DISTINCT family_id) FROM sessions WHERE user_id = $1`, first.Profile.User.ID); n != 2 {
		t.Errorf("%d session families, want 2 (one per sign-in)", n)
	}
}

func TestOTPSignInNeedsPIN(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name       string
		pin        *string
		want       error
		wantFailed int
	}{
		{"no pin", nil, model.ErrPINRequired, 0},
		{"wrong pin", strp(wrongPIN), model.ErrPINInvalid, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{"tok": rina})
			user := env.pinUser(t).Profile.User
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})

			// Act
			_, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0), PIN: tt.pin}, nil)

			// Assert
			wantErr(t, err, tt.want)
			if status, _, attempts := env.otpRow(t, ch.ID); status != "pending" || attempts != 0 {
				t.Errorf("request %s with %d attempts, want pending with 0", status, attempts)
			}
			if n := env.count(t, `SELECT pin_failed_count FROM users WHERE id = $1`, user.ID); n != tt.wantFailed {
				t.Errorf("pin_failed_count %d, want %d", n, tt.wantFailed)
			}
			res, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0), PIN: strp(goodPIN)}, nil)
			if err != nil || res.Auth.Profile.User.ID != user.ID {
				t.Errorf("retry with the right PIN: %v", err)
			}
		})
	}
}

func TestOTPSignInPINLocked(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	env.pinUser(t)
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
	for range pinCfg.PIN.MaxAttempts - 1 {
		_, _ = env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0), PIN: strp(wrongPIN)}, nil)
	}

	// Act
	_, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0), PIN: strp(wrongPIN)}, nil)

	// Assert
	wantErr(t, err, model.ErrPINLocked)
	var merr *model.Error
	if errors.As(err, &merr) && merr.RetryAfter != pinCfg.PIN.LockoutDuration {
		t.Errorf("Retry-After %v, want %v", merr.RetryAfter, pinCfg.PIN.LockoutDuration)
	}
}

func TestOTPWrongCodeCountsDownAndLocks(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{})
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
	wrong := "000000"
	if wrong == code(ch.ID, 0) {
		wrong = "000001"
	}
	var remaining []any
	for range model.OTPMaxAttempts - 1 {
		_, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: wrong}, nil)
		var merr *model.Error
		if !errors.As(err, &merr) || merr.Code != "otp_invalid" {
			t.Fatalf("wrong code: %v, want otp_invalid", err)
		}
		remaining = append(remaining, merr.Extensions["attempts_remaining"])
	}

	// Act
	_, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: wrong}, nil)

	// Assert
	wantErr(t, err, model.ErrOTPTooManyAttempts)
	if want := []any{4, 3, 2, 1}; len(remaining) != 4 || remaining[0] != want[0] || remaining[3] != want[3] {
		t.Errorf("attempts_remaining %v, want %v", remaining, want)
	}
	if status, _, attempts := env.otpRow(t, ch.ID); status != "locked" || attempts != model.OTPMaxAttempts {
		t.Errorf("request %s with %d attempts, want locked with 5", status, attempts)
	}
	_, err = env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, nil)
	wantErr(t, err, model.ErrOTPTooManyAttempts)
}

func TestOTPVerifyRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name  string
		setup func(t *testing.T, env authEnv) uuid.UUID
		want  error
	}{
		{"unknown request", func(*testing.T, authEnv) uuid.UUID { return uuid.Must(uuid.NewV7()) }, model.ErrOTPNotFound},
		{"expired", func(t *testing.T, env authEnv) uuid.UUID {
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			env.clock.Advance(otpCfg.TTL)
			return ch.ID
		}, model.ErrOTPExpired},
		{"replaced by a new request", func(t *testing.T, env authEnv) uuid.UUID {
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			return ch.ID
		}, model.ErrOTPExpired},
		{"already used", func(t *testing.T, env authEnv) uuid.UUID {
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			if _, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, nil); err != nil {
				t.Fatalf("Verify: %v", err)
			}
			return ch.ID
		}, model.ErrOTPAlreadyUsed},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{})
			id := tt.setup(t, env)

			// Act
			_, err := env.otp.Verify(context.Background(), id, OTPVerify{Code: code(id, 0)}, nil)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestOTPConcurrentVerifySignsInOnce(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{})
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
	const n = 5
	errs := make([]error, n)
	var wg sync.WaitGroup

	// Act
	for i := range n {
		wg.Go(func() {
			_, errs[i] = env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, nil)
		})
	}
	wg.Wait()

	// Assert
	ok := 0
	for i, err := range errs {
		switch {
		case err == nil:
			ok++
		case !errors.Is(err, model.ErrOTPAlreadyUsed):
			t.Errorf("verify %d: %v", i, err)
		}
	}
	if ok != 1 {
		t.Errorf("%d verifies succeeded, want 1", ok)
	}
	if users := env.count(t, `SELECT count(*) FROM users`); users != 1 {
		t.Errorf("%d users, want 1", users)
	}
}

func TestOTPConcurrentRequestsLeaveOnePending(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{})
	const n = 5
	errs := make([]error, n)
	var wg sync.WaitGroup

	// Act
	for i := range n {
		wg.Go(func() {
			_, errs[i] = env.otp.Request(context.Background(),
				OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email, Device: android})
		})
	}
	wg.Wait()

	// Assert
	for i, err := range errs {
		if err != nil {
			t.Errorf("request %d: %v", i, err)
		}
	}
	if pending := env.count(t, `SELECT count(*) FROM email_otp_requests WHERE email = $1 AND status = 'pending'`, rina.Email); pending != 1 {
		t.Errorf("%d pending requests, want 1", pending)
	}
	if total := env.count(t, `SELECT count(*) FROM email_otp_requests WHERE email = $1`, rina.Email); total != n {
		t.Errorf("%d requests, want %d", total, n)
	}
}

func TestOTPResend(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{})
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
	env.clock.Advance(time.Minute)

	// Act
	again, err := env.otp.Resend(context.Background(), ch.ID, nil)

	// Assert
	if err != nil {
		t.Fatalf("Resend: %v", err)
	}
	if again.ID != ch.ID || !again.ExpiresAt.Equal(env.clock.Now().Add(otpCfg.TTL)) {
		t.Errorf("challenge %+v", again)
	}
	sends := queued[jobs.EmailOTPArgs](t, env.pool, jobs.EmailOTPArgs{}.Kind())
	if len(sends) != 2 || sends[1].ResendCount != 1 {
		t.Errorf("email.otp jobs %+v, want a second one for resend 1", sends)
	}
	if code(ch.ID, 0) != code(ch.ID, 1) {
		_, err = env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, nil)
		wantErr(t, err, model.ErrOTPInvalid)
	}
	if _, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 1)}, nil); err != nil {
		t.Errorf("new code: %v", err)
	}
}

func TestOTPResendLimits(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name    string
		resends int
		wait    time.Duration
		want    error
	}{
		{"too soon", 0, 40 * time.Second, model.ErrRateLimitExceeded},
		{"no resends left", model.OTPMaxResends, time.Minute, model.ErrOTPTooManyAttempts},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{})
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email})
			for range tt.resends {
				env.clock.Advance(time.Minute)
				if _, err := env.otp.Resend(context.Background(), ch.ID, nil); err != nil {
					t.Fatalf("Resend: %v", err)
				}
			}
			env.clock.Advance(tt.wait)

			// Act
			_, err := env.otp.Resend(context.Background(), ch.ID, nil)

			// Assert
			wantErr(t, err, tt.want)
			var merr *model.Error
			if errors.Is(err, model.ErrRateLimitExceeded) && errors.As(err, &merr) && merr.RetryAfter != 20*time.Second {
				t.Errorf("Retry-After %v, want 20s", merr.RetryAfter)
			}
		})
	}
}

func TestOTPRequestLimits(t *testing.T) {
	// Arrange
	t.Parallel()
	ip := netip.MustParseAddr("203.0.113.7")
	tests := []struct {
		name   string
		limit  func(*OTPService)
		second OTPStart
	}{
		{"per email", func(s *OTPService) { s.cfg.LimitPerEmail = 1 },
			OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email}},
		{"per IP", func(s *OTPService) { s.cfg.LimitPerIP = 1 },
			OTPStart{Purpose: model.OTPPurposeSignIn, Email: budi.Email, IP: &ip}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{})
			tt.limit(env.otp)
			env.request(t, OTPStart{Purpose: model.OTPPurposeSignIn, Email: rina.Email, IP: &ip})

			// Act
			_, err := env.otp.Request(context.Background(), tt.second)

			// Assert
			wantErr(t, err, model.ErrRateLimitExceeded)
			var merr *model.Error
			if errors.As(err, &merr) && merr.RetryAfter != otpCfg.LimitWindow {
				t.Errorf("Retry-After %v, want %v", merr.RetryAfter, otpCfg.LimitWindow)
			}
		})
	}
}

func TestOTPResetPINUnknownEmail(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{})
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeResetPIN, Email: "nobody@gmail.com"})

	// Act
	_, err := env.otp.Verify(context.Background(), ch.ID,
		OTPVerify{Code: code(ch.ID, 0), NewPIN: strp(otherPIN), NewPINConfirmation: strp(otherPIN)}, nil)

	// Assert
	wantErr(t, err, model.ErrOTPInvalid)
	if ch.EmailMasked != "no•••••@gmail.com" || ch.AttemptsRemaining != model.OTPMaxAttempts {
		t.Errorf("challenge %+v", ch)
	}
	if _, send, attempts := env.otpRow(t, ch.ID); send != "skipped" || attempts != 1 {
		t.Errorf("send_status %s with %d attempts, want skipped with 1", send, attempts)
	}
	if sends := queued[jobs.EmailOTPArgs](t, env.pool, jobs.EmailOTPArgs{}.Kind()); len(sends) != 0 {
		t.Errorf("email.otp jobs %+v, want none", sends)
	}
}

func TestOTPResetPIN(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	old := env.pinUser(t)
	user := old.Profile.User
	for range pinCfg.PIN.MaxAttempts {
		_ = env.pins.Verify(context.Background(), user.ID, wrongPIN)
	}
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeResetPIN, Email: rina.Email})

	// Act
	res, err := env.otp.Verify(context.Background(), ch.ID,
		OTPVerify{Code: code(ch.ID, 0), NewPIN: strp(otherPIN), NewPINConfirmation: strp(otherPIN)}, nil)

	// Assert
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if res.Purpose != model.OTPPurposeResetPIN || res.Auth == nil || res.Auth.IsNewUser || res.Auth.Profile.User.ID != user.ID {
		t.Fatalf("result %+v", res)
	}
	if got := env.revokedReason(t, old.Tokens.RefreshToken); got != "pin_reset" {
		t.Errorf("old session revoked_reason %q, want pin_reset", got)
	}
	if got := env.revokedReason(t, res.Auth.Tokens.RefreshToken); got != "" {
		t.Errorf("new session revoked (%s)", got)
	}
	if err := env.pins.Verify(context.Background(), user.ID, otherPIN); err != nil {
		t.Errorf("new PIN after reset: %v", err)
	}
}

func TestOTPResetPINValidatesNewPIN(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name  string
		in    OTPVerify
		field string
	}{
		{"missing", OTPVerify{}, "new_pin"},
		{"mismatch", OTPVerify{NewPIN: strp(otherPIN), NewPINConfirmation: strp(goodPIN)}, "new_pin_confirmation"},
		{"too weak", OTPVerify{NewPIN: strp("111111"), NewPINConfirmation: strp("111111")}, "new_pin"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{"tok": rina})
			env.pinUser(t)
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeResetPIN, Email: rina.Email})
			tt.in.Code = code(ch.ID, 0)

			// Act
			_, err := env.otp.Verify(context.Background(), ch.ID, tt.in, nil)

			// Assert
			var merr *model.Error
			if !errors.As(err, &merr) || merr.Code != "validation_error" || merr.Fields[0].Field != tt.field {
				t.Fatalf("err %v, want validation_error on %s", err, tt.field)
			}
			if status, _, attempts := env.otpRow(t, ch.ID); status != "pending" || attempts != 0 {
				t.Errorf("request %s with %d attempts, want untouched", status, attempts)
			}
		})
	}
}

func TestOTPChangeEmail(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newAuthEnv(t, accounts{"tok": rina})
	current := env.pinUser(t)
	other := env.signIn(t, "tok")
	caller := env.caller(t, current)
	newEmail := "rina.baru@gmail.com"
	ch := env.request(t, OTPStart{Purpose: model.OTPPurposeChangeEmail, Email: newEmail, PIN: strp(goodPIN), Caller: caller})

	// Act
	res, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, caller)

	// Assert
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if res.Auth != nil || res.User == nil || res.User.User.Email == nil || *res.User.User.Email != newEmail {
		t.Fatalf("result %+v", res)
	}
	if got := env.revokedReason(t, other.Tokens.RefreshToken); got != "email_changed" {
		t.Errorf("other session revoked as %q, want email_changed", got)
	}
	if got := env.revokedReason(t, current.Tokens.RefreshToken); got != "" {
		t.Errorf("current session revoked as %q, want active", got)
	}
	notices := queued[jobs.EmailChangedNoticeArgs](t, env.pool, jobs.EmailChangedNoticeArgs{}.Kind())
	if len(notices) != 1 || notices[0].OldEmail != rina.Email || notices[0].UserID != caller.UserID {
		t.Errorf("notices %+v, want one to %s", notices, rina.Email)
	}
}

func TestOTPChangeEmailRequestRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name      string
		email     string
		pin       *string
		anonymous bool
		want      error
	}{
		{"no access token", "baru@gmail.com", strp(goodPIN), true, model.ErrUnauthorized},
		{"no pin", "baru@gmail.com", nil, false, model.ErrValidation},
		{"wrong pin", "baru@gmail.com", strp(wrongPIN), false, model.ErrPINInvalid},
		{"same email", rina.Email, strp(goodPIN), false, model.ErrValidation},
		{"email taken", budi.Email, strp(goodPIN), false, model.ErrEmailAlreadyRegistered},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{"tok": rina, "budi": budi})
			caller := env.caller(t, env.pinUser(t))
			env.signIn(t, "budi")
			if tt.anonymous {
				caller = nil
			}

			// Act
			_, err := env.otp.Request(context.Background(), OTPStart{
				Purpose: model.OTPPurposeChangeEmail, Email: tt.email, PIN: tt.pin, Device: android, Caller: caller,
			})

			// Assert
			wantErr(t, err, tt.want)
			if n := env.count(t, `SELECT count(*) FROM email_otp_requests WHERE purpose = 'change_email'`); n != 0 {
				t.Errorf("%d change_email requests stored, want 0", n)
			}
		})
	}
}

func TestOTPChangeEmailVerifyRejects(t *testing.T) {
	// Arrange
	t.Parallel()
	newEmail := "rina.baru@gmail.com"
	tests := []struct {
		name   string
		caller func(t *testing.T, env authEnv, rina *Caller) *Caller
		want   error
	}{
		{"another account", func(t *testing.T, env authEnv, _ *Caller) *Caller {
			return env.caller(t, env.signIn(t, "budi"))
		}, model.ErrOTPNotFound},
		{"no access token", func(*testing.T, authEnv, *Caller) *Caller { return nil }, model.ErrOTPNotFound},
		{"email taken meanwhile", func(t *testing.T, env authEnv, rina *Caller) *Caller {
			env.signInEmail(t, newEmail, nil)
			return rina
		}, model.ErrEmailAlreadyRegistered},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newAuthEnv(t, accounts{"tok": rina, "budi": budi})
			rinaCaller := env.caller(t, env.pinUser(t))
			ch := env.request(t, OTPStart{Purpose: model.OTPPurposeChangeEmail, Email: newEmail, PIN: strp(goodPIN), Caller: rinaCaller})
			caller := tt.caller(t, env, rinaCaller)

			// Act
			_, err := env.otp.Verify(context.Background(), ch.ID, OTPVerify{Code: code(ch.ID, 0)}, caller)

			// Assert
			wantErr(t, err, tt.want)
			if n := env.count(t, `SELECT count(*) FROM users WHERE id = $1 AND email = $2`, rinaCaller.UserID, rina.Email); n != 1 {
				t.Error("email changed despite the error")
			}
		})
	}
}
