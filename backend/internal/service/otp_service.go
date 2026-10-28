package service

import (
	"context"
	"errors"
	"log/slog"
	"net/netip"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// Caller is the signed-in account behind a request, when it sent a Bearer
// token. change_email needs one; the other purposes ignore it.
type Caller struct {
	UserID    uuid.UUID
	SessionID uuid.UUID
}

// OTPStart asks for an email code.
type OTPStart struct {
	Purpose model.OTPPurpose
	Email   string // the new address for change_email
	Device  Device // the session sign_in and reset_pin create
	PIN     *string
	IP      *netip.Addr
	Caller  *Caller
}

// OTPChallenge is what the app shows while the user reads their email.
type OTPChallenge struct {
	ID                uuid.UUID
	Purpose           model.OTPPurpose
	EmailMasked       string
	ExpiresAt         time.Time
	ResendAvailableAt time.Time
	AttemptsRemaining int
}

// OTPVerify is the code and, depending on the purpose, the PIN fields.
type OTPVerify struct {
	Code               string
	PIN                *string // sign_in, for an account with a PIN
	NewPIN             *string // reset_pin
	NewPINConfirmation *string // reset_pin
}

// OTPResult is the outcome of a verified code: Auth for sign_in and
// reset_pin, User for change_email.
type OTPResult struct {
	Purpose model.OTPPurpose
	Auth    *SignInResult
	User    *Profile
}

// OTPService signs users in with a 6-digit code sent to their email
// (FR-AUTH-01), and uses the same codes to reset a forgotten PIN
// (FR-AUTH-05) and to move the account to a new email (FR-AUTH-06). Codes
// are derived from OTP_SECRET, the row ID and its resend count, so only their
// hash is stored; the email.otp job derives the code again to send it.
type OTPService struct {
	tx       *repository.TxManager
	users    *repository.UserRepository
	sessions *repository.SessionRepository
	otps     *repository.OTPRepository
	pins     *PINService
	auth     *AuthService
	enqueuer *jobs.Enqueuer
	store    storage.Storage
	clock    clock.Clock
	log      *slog.Logger
	cfg      config.OTP
	secret   []byte
}

func NewOTPService(
	tx *repository.TxManager,
	users *repository.UserRepository,
	sessions *repository.SessionRepository,
	otps *repository.OTPRepository,
	pins *PINService,
	auth *AuthService,
	enqueuer *jobs.Enqueuer,
	store storage.Storage,
	clk clock.Clock,
	log *slog.Logger,
	cfg *config.Config,
) *OTPService {
	return &OTPService{
		tx: tx, users: users, sessions: sessions, otps: otps, pins: pins, auth: auth, enqueuer: enqueuer,
		store: store, clock: clk, log: log, cfg: cfg.OTP, secret: []byte(cfg.OTP.Secret),
	}
}

// Request creates a code request and queues its email in the same
// transaction, cancelling any pending request for the same email and
// purpose. A reset_pin request for an unknown email is stored as skipped and
// sends nothing, but answers the same way, so the response never reveals
// which emails have accounts. change_email checks the caller's PIN first,
// so wrong PINs count towards the lock.
func (s *OTPService) Request(ctx context.Context, in OTPStart) (OTPChallenge, error) {
	if !in.Purpose.IsValid() {
		return OTPChallenge{}, model.NewValidationError(model.FieldError{
			Field: "purpose", Code: model.FieldInvalidChoice, Message: "Must be sign_in, reset_pin or change_email.",
		})
	}
	email, err := utils.NormalizeEmail("email", in.Email)
	if err != nil {
		return OTPChallenge{}, err
	}
	if in.Purpose == model.OTPPurposeChangeEmail {
		if in.Caller == nil {
			return OTPChallenge{}, model.ErrUnauthorized
		}
		if in.PIN == nil {
			return OTPChallenge{}, model.NewValidationError(model.FieldError{
				Field: "pin", Code: model.FieldRequired, Message: "Changing the email needs the current PIN.",
			})
		}
	}
	now := s.clock.Now()
	if err := s.checkLimits(ctx, email, in.IP, now); err != nil {
		return OTPChallenge{}, err
	}

	var row model.OTPRequest
	create := func(ctx context.Context) error {
		r := model.OTPRequest{
			ID:             uuid.Must(uuid.NewV7()),
			Purpose:        in.Purpose,
			Email:          email,
			SendStatus:     model.OTPSendStatusQueued,
			DevicePlatform: in.Device.Platform,
			FCMToken:       in.Device.FCMToken,
			RequesterIP:    in.IP,
			ExpiresAt:      now.Add(s.cfg.TTL),
		}
		if in.Device.Name != "" {
			r.DeviceName = &in.Device.Name
		}
		switch in.Purpose {
		case model.OTPPurposeResetPIN:
			u, err := s.users.GetByEmail(ctx, email)
			switch {
			case err == nil:
				r.UserID = &u.ID
			case errors.Is(err, repository.ErrNotFound):
				r.SendStatus = model.OTPSendStatusSkipped
			default:
				return err
			}
		case model.OTPPurposeChangeEmail:
			if err := s.checkNewEmail(ctx, in.Caller.UserID, email); err != nil {
				return err
			}
			r.UserID = &in.Caller.UserID
		}
		r.CodeHash = security.OTPCodeHash(s.secret, r.ID, security.OTPCode(s.secret, r.ID, 0))

		// Under the lock, a concurrent request for this email and purpose has
		// either committed its pending row, which the cancel below sees, or
		// waits for ours.
		if err := s.otps.LockEmail(ctx, email, in.Purpose); err != nil {
			return err
		}
		if _, err := s.otps.CancelPending(ctx, email, in.Purpose); err != nil {
			return err
		}
		created, err := s.otps.Create(ctx, r, now)
		if err != nil {
			return err
		}
		row = created
		return s.queueCode(ctx, created)
	}
	if in.Purpose == model.OTPPurposeChangeEmail {
		err = s.pins.checkPIN(ctx, in.Caller.UserID, *in.PIN, create)
	} else {
		err = s.tx.WithTx(ctx, create)
	}
	if err != nil {
		return OTPChallenge{}, err
	}
	return s.challenge(row), nil
}

// Resend replaces the code of a pending request, resets its attempts and
// moves its expiry. It is available OTP_RESEND_INTERVAL after the previous
// send, at most model.OTPMaxResends times per request.
func (s *OTPService) Resend(ctx context.Context, otpID uuid.UUID, caller *Caller) (OTPChallenge, error) {
	now := s.clock.Now()
	var row model.OTPRequest
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		r, err := s.lockRequest(ctx, otpID, caller)
		if err != nil {
			return err
		}
		if err := checkStatus(r); err != nil {
			return err
		}
		if int(r.ResendCount) >= model.OTPMaxResends {
			return model.ErrOTPTooManyAttempts.WithDetail("No resends left; request a new code.")
		}
		if wait := r.ResendAvailableAt(s.cfg.ResendInterval).Sub(now); wait > 0 {
			return model.ErrRateLimitExceeded.WithDetail("Wait before sending a new code.").WithRetryAfter(wait)
		}
		code := security.OTPCode(s.secret, r.ID, int(r.ResendCount)+1)
		row, err = s.otps.Resend(ctx, r.ID, security.OTPCodeHash(s.secret, r.ID, code),
			now, now.Add(s.cfg.TTL), now.Add(-s.cfg.ResendInterval))
		if errors.Is(err, repository.ErrNotFound) {
			// The checks above hold under the row lock, so this is a bug.
			return errors.New("resend: pending request did not update")
		}
		if err != nil {
			return err
		}
		return s.queueCode(ctx, row)
	})
	if err != nil {
		return OTPChallenge{}, err
	}
	return s.challenge(row), nil
}

// Verify checks the code and completes what the request was for, in one
// transaction with consuming it. A wrong code is counted and committed before
// otp_invalid (with attempts_remaining) or, at the fifth, otp_too_many_attempts
// is returned. For sign_in, an account with a PIN must send it as well: no PIN
// is pin_required and a wrong one counts towards the PIN lock, and in both
// cases the code stays valid.
func (s *OTPService) Verify(ctx context.Context, otpID uuid.UUID, in OTPVerify, caller *Caller) (OTPResult, error) {
	// The purpose never changes, so an unlocked read tells which fields to
	// check before the slow PIN hash, which runs before any lock is taken.
	r, err := s.otps.Get(ctx, otpID)
	if errors.Is(err, repository.ErrNotFound) {
		return OTPResult{}, model.ErrOTPNotFound
	}
	if err != nil {
		return OTPResult{}, err
	}
	var newPINHash string
	if r.Purpose == model.OTPPurposeResetPIN {
		if newPINHash, err = s.newPINHash(in); err != nil {
			return OTPResult{}, err
		}
	}

	now := s.clock.Now()
	var res OTPResult
	var user model.User
	var sess model.Session
	var refresh string
	var failure error
	verify := func(ctx context.Context) error {
		res, failure = OTPResult{}, nil
		row, err := s.lockRequest(ctx, otpID, caller)
		if err != nil {
			return err
		}
		if err := checkStatus(row); err != nil {
			return err
		}
		if row.IsExpired(now) {
			return model.ErrOTPExpired
		}
		// A skipped reset_pin request has no account and no email was sent,
		// so no code can match it.
		if row.UserID == nil && row.Purpose == model.OTPPurposeResetPIN ||
			!security.OTPCodeMatches(s.secret, row.ID, in.Code, row.CodeHash) {
			failure, err = s.recordFailure(ctx, row.ID)
			return err
		}

		res.Purpose = row.Purpose
		switch row.Purpose {
		case model.OTPPurposeSignIn:
			var isNew bool
			user, isNew, failure, err = s.signInUser(ctx, row, in.PIN, now)
			if err != nil || failure != nil {
				return err
			}
			res.Auth = &SignInResult{IsNewUser: isNew}
		case model.OTPPurposeResetPIN:
			if user, err = s.lockOwner(ctx, row); err != nil {
				return err
			}
			if err := s.users.SetPIN(ctx, user.ID, newPINHash); err != nil {
				return err
			}
			if _, err := s.sessions.RevokeAll(ctx, user.ID, model.RevokedReasonPINReset, now); err != nil {
				return err
			}
			res.Auth = &SignInResult{}
		case model.OTPPurposeChangeEmail:
			if user, err = s.changeEmail(ctx, row, caller.SessionID, now); err != nil {
				return err
			}
		}

		if _, err := s.otps.Consume(ctx, row.ID, user.ID, now); err != nil {
			return err
		}
		if res.Auth == nil {
			return nil
		}
		device := Device{Platform: row.DevicePlatform, FCMToken: row.FCMToken}
		if row.DeviceName != nil {
			device.Name = *row.DeviceName
		}
		sess, refresh, err = s.auth.createSession(ctx, user.ID, uuid.Must(uuid.NewV7()), device, now)
		return err
	}
	err = s.tx.WithTx(ctx, verify)
	if errors.Is(err, repository.ErrDuplicate) {
		// A concurrent first sign-in created the account for this email, or
		// another account took the new email, between our lookup and write;
		// this time the lookup sees it.
		err = s.tx.WithTx(ctx, verify)
	}
	if errors.Is(err, repository.ErrDuplicate) && r.Purpose == model.OTPPurposeChangeEmail {
		return OTPResult{}, model.ErrEmailAlreadyRegistered
	}
	if err != nil {
		return OTPResult{}, err
	}
	if failure != nil {
		return OTPResult{}, failure
	}

	profile, err := profileOf(ctx, s.store, user)
	if err != nil {
		return OTPResult{}, err
	}
	if res.Auth == nil {
		res.User = &profile
		return res, nil
	}
	res.Auth.Profile = profile
	if res.Auth.Tokens, err = s.auth.issue(user.ID, sess.ID, refresh); err != nil {
		return OTPResult{}, err
	}
	return res, nil
}

// signInUser finds the account for a verified sign_in code, checking its PIN
// if it has one, or creates it with its default settings. A wrong PIN is
// returned as failure with a nil err, so the count commits and the code stays
// pending.
func (s *OTPService) signInUser(ctx context.Context, row model.OTPRequest, pin *string, now time.Time) (user model.User, isNew bool, failure, err error) {
	user, err = s.users.GetByEmailForUpdate(ctx, row.Email)
	if errors.Is(err, repository.ErrNotFound) {
		if user, err = s.users.Create(ctx, uuid.Must(uuid.NewV7()), row.Email, now); err != nil {
			return model.User{}, false, nil, err
		}
		return user, true, nil, s.users.CreateSettings(ctx, user.ID)
	}
	if err != nil {
		return model.User{}, false, nil, err
	}
	if user.HasPIN() {
		if pin == nil {
			return model.User{}, false, nil, model.ErrPINRequired
		}
		if failure, err = s.pins.attemptPIN(ctx, user, *pin); err != nil || failure != nil {
			return model.User{}, false, failure, err
		}
	}
	user, err = s.users.UpdateEmail(ctx, user.ID, row.Email, now)
	return user, false, nil, err
}

// changeEmail moves the requester's account to the verified new address,
// signs out every other session and tells the old address.
func (s *OTPService) changeEmail(ctx context.Context, row model.OTPRequest, sessionID uuid.UUID, now time.Time) (model.User, error) {
	current, err := s.lockOwner(ctx, row)
	if err != nil {
		return model.User{}, err
	}
	if err := s.checkNewEmail(ctx, current.ID, row.Email); err != nil {
		return model.User{}, err
	}
	user, err := s.users.UpdateEmail(ctx, current.ID, row.Email, now)
	if err != nil {
		return model.User{}, err
	}
	if _, err := s.sessions.RevokeOthers(ctx, current.ID, sessionID, model.RevokedReasonEmailChanged, now); err != nil {
		return model.User{}, err
	}
	if current.Email == nil {
		return user, nil
	}
	return user, s.enqueuer.Enqueue(ctx, river.InsertManyParams{
		Args: jobs.EmailChangedNoticeArgs{UserID: user.ID, OldEmail: *current.Email, ChangedAt: now},
	})
}

// checkNewEmail refuses the user's own address and one another account has.
func (s *OTPService) checkNewEmail(ctx context.Context, userID uuid.UUID, email string) error {
	other, err := s.users.GetByEmail(ctx, email)
	switch {
	case errors.Is(err, repository.ErrNotFound):
		return nil
	case err != nil:
		return err
	case other.ID == userID:
		return model.NewValidationError(model.FieldError{
			Field: "email", Code: model.FieldInvalidFormat, Message: "This is already your email.",
		})
	}
	return model.ErrEmailAlreadyRegistered
}

// checkLimits applies OTP_LIMIT_PER_EMAIL and OTP_LIMIT_PER_IP over
// OTP_LIMIT_WINDOW. Retry-After is the whole window, since the oldest
// counted request is not known.
func (s *OTPService) checkLimits(ctx context.Context, email string, ip *netip.Addr, now time.Time) error {
	since := now.Add(-s.cfg.LimitWindow)
	n, err := s.otps.CountRecentByEmail(ctx, email, since)
	if err != nil {
		return err
	}
	if n >= int64(s.cfg.LimitPerEmail) {
		return model.ErrRateLimitExceeded.WithDetail("Too many codes for this email.").WithRetryAfter(s.cfg.LimitWindow)
	}
	if ip == nil {
		return nil
	}
	if n, err = s.otps.CountRecentByIP(ctx, *ip, since); err != nil {
		return err
	}
	if n >= int64(s.cfg.LimitPerIP) {
		return model.ErrRateLimitExceeded.WithDetail("Too many codes from this network.").WithRetryAfter(s.cfg.LimitWindow)
	}
	return nil
}

// lockRequest row-locks the request. A change_email request belongs to the
// account that asked for it; anyone else gets otp_not_found, so its
// existence never leaks.
func (s *OTPService) lockRequest(ctx context.Context, otpID uuid.UUID, caller *Caller) (model.OTPRequest, error) {
	row, err := s.otps.GetForUpdate(ctx, otpID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.OTPRequest{}, model.ErrOTPNotFound
	}
	if err != nil {
		return model.OTPRequest{}, err
	}
	if row.Purpose == model.OTPPurposeChangeEmail &&
		(caller == nil || row.UserID == nil || *row.UserID != caller.UserID) {
		return model.OTPRequest{}, model.ErrOTPNotFound
	}
	return row, nil
}

// lockOwner row-locks the account a reset_pin or change_email request was
// made for. Deleting the account cancels its requests, so a missing owner
// means the request is gone too.
func (s *OTPService) lockOwner(ctx context.Context, row model.OTPRequest) (model.User, error) {
	if row.UserID == nil {
		return model.User{}, model.ErrOTPNotFound
	}
	user, err := s.users.GetByIDForUpdate(ctx, *row.UserID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.User{}, model.ErrOTPNotFound
	}
	return user, err
}

// recordFailure counts a wrong code and returns the error to report once the
// count is committed.
func (s *OTPService) recordFailure(ctx context.Context, id uuid.UUID) (failure, err error) {
	row, err := s.otps.RecordFailure(ctx, id)
	if err != nil {
		return nil, err
	}
	if row.Status == model.OTPStatusLocked {
		return model.ErrOTPTooManyAttempts, nil
	}
	return model.ErrOTPInvalid.WithExtensions(map[string]any{"attempts_remaining": row.AttemptsRemaining()}), nil
}

// newPINHash checks reset_pin's new PIN and its confirmation and hashes it.
func (s *OTPService) newPINHash(in OTPVerify) (string, error) {
	var fields []model.FieldError
	if in.NewPIN == nil {
		fields = append(fields, model.FieldError{Field: "new_pin", Code: model.FieldRequired, Message: "Resetting the PIN needs a new PIN."})
	}
	if in.NewPINConfirmation == nil {
		fields = append(fields, model.FieldError{Field: "new_pin_confirmation", Code: model.FieldRequired, Message: "Repeat the new PIN."})
	} else if in.NewPIN != nil && *in.NewPIN != *in.NewPINConfirmation {
		fields = append(fields, model.FieldError{Field: "new_pin_confirmation", Code: model.FieldMismatch, Message: "Does not match new_pin."})
	}
	if len(fields) > 0 {
		return "", model.NewValidationError(fields...)
	}
	return s.pins.validateAndHash("new_pin", *in.NewPIN)
}

// queueCode queues the email for the request's current code, unless nothing
// is sent for it (a skipped reset_pin).
func (s *OTPService) queueCode(ctx context.Context, row model.OTPRequest) error {
	if row.SendStatus == model.OTPSendStatusSkipped {
		return nil
	}
	return s.enqueuer.Enqueue(ctx, river.InsertManyParams{
		Args: jobs.EmailOTPArgs{OTPID: row.ID, ResendCount: row.ResendCount},
	})
}

func (s *OTPService) challenge(row model.OTPRequest) OTPChallenge {
	return OTPChallenge{
		ID:                row.ID,
		Purpose:           row.Purpose,
		EmailMasked:       utils.MaskEmail(row.Email),
		ExpiresAt:         row.ExpiresAt,
		ResendAvailableAt: row.ResendAvailableAt(s.cfg.ResendInterval),
		AttemptsRemaining: row.AttemptsRemaining(),
	}
}

// checkStatus refuses a request that can no longer be resent or verified.
func checkStatus(row model.OTPRequest) error {
	switch row.Status {
	case model.OTPStatusPending:
		return nil
	case model.OTPStatusConsumed:
		return model.ErrOTPAlreadyUsed
	case model.OTPStatusLocked:
		return model.ErrOTPTooManyAttempts
	}
	return model.ErrOTPExpired
}
