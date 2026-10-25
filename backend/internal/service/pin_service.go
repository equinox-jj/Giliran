package service

import (
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// PINService manages the app PIN (FR-AUTH-02..05): set once, verify to
// unlock, change with the current PIN, and reset after a fresh OTP. Wrong
// PINs are counted on the user row; PIN_MAX_ATTEMPTS failures lock PIN entry
// for PIN_LOCKOUT_DURATION.
type PINService struct {
	tx          *repository.TxManager
	users       *repository.UserRepository
	sessions    *repository.SessionRepository
	hasher      *security.PINHasher
	verifier    firebase.AuthVerifier
	clock       clock.Clock
	maxAttempts int
	lockout     time.Duration
}

func NewPINService(
	tx *repository.TxManager,
	users *repository.UserRepository,
	sessions *repository.SessionRepository,
	hasher *security.PINHasher,
	verifier firebase.AuthVerifier,
	clk clock.Clock,
	cfg *config.Config,
) *PINService {
	return &PINService{
		tx: tx, users: users, sessions: sessions, hasher: hasher, verifier: verifier, clock: clk,
		maxAttempts: cfg.PIN.MaxAttempts, lockout: cfg.PIN.LockoutDuration,
	}
}

// Set stores the first PIN. A user who already has one gets pin_already_set.
func (s *PINService) Set(ctx context.Context, userID uuid.UUID, pin string) error {
	hash, err := s.validateAndHash("pin", pin)
	if err != nil {
		return err
	}
	return s.tx.WithTx(ctx, func(ctx context.Context) error {
		user, err := s.lockUser(ctx, userID)
		if err != nil {
			return err
		}
		if user.HasPIN() {
			return model.ErrPINAlreadySet
		}
		return s.users.SetPIN(ctx, userID, hash)
	})
}

// Verify checks the PIN to unlock the app.
func (s *PINService) Verify(ctx context.Context, userID uuid.UUID, pin string) error {
	return s.checkPIN(ctx, userID, pin, nil)
}

// Change replaces the PIN after checking the current one. Wrong current PINs
// count towards the lock. Other sessions stay signed in (FR-AUTH-04).
func (s *PINService) Change(ctx context.Context, userID uuid.UUID, currentPIN, newPIN string) error {
	hash, err := s.validateAndHash("new_pin", newPIN)
	if err != nil {
		return err
	}
	return s.checkPIN(ctx, userID, currentPIN, func(ctx context.Context) error {
		return s.users.SetPIN(ctx, userID, hash)
	})
}

// Reset sets a new PIN after a fresh OTP to the account's own number, clears
// any lock, and signs out every session except sessionID (FR-AUTH-05).
func (s *PINService) Reset(ctx context.Context, userID, sessionID uuid.UUID, idToken, newPIN string) error {
	hash, err := s.validateAndHash("new_pin", newPIN)
	if err != nil {
		return err
	}
	identity, err := s.verifier.Verify(ctx, idToken)
	if err != nil {
		return err
	}
	return s.tx.WithTx(ctx, func(ctx context.Context) error {
		user, err := s.lockUser(ctx, userID)
		if err != nil {
			return err
		}
		if !ownsIdentity(user, identity) {
			return model.ErrOTPInvalid.WithDetail("The OTP was not sent to this account's phone number.")
		}
		if err := s.users.SetPIN(ctx, userID, hash); err != nil {
			return err
		}
		_, err = s.sessions.RevokeOthers(ctx, userID, sessionID, model.RevokedReasonPINReset, s.clock.Now())
		return err
	})
}

// checkPIN verifies pin under a row lock and runs onSuccess in the same
// transaction when it matches. A wrong PIN is recorded and committed before
// pin_invalid or pin_locked is returned.
func (s *PINService) checkPIN(ctx context.Context, userID uuid.UUID, pin string, onSuccess func(context.Context) error) error {
	now := s.clock.Now()
	var failure error
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		user, err := s.lockUser(ctx, userID)
		if err != nil {
			return err
		}
		if !user.HasPIN() {
			return model.ErrPINNotSet
		}
		if user.IsPINLocked(now) {
			return s.lockedError(user.PINLockedUntil.Sub(now))
		}
		ok, err := s.hasher.Verify(pin, *user.PINHash)
		if err != nil {
			return fmt.Errorf("verify pin: %w", err)
		}
		if !ok {
			failed := int(user.PINFailedCount) + 1
			var lockedUntil *time.Time
			failure = model.ErrPINInvalid
			if failed >= s.maxAttempts {
				until := now.Add(s.lockout)
				lockedUntil, failed = &until, 0
				failure = s.lockedError(s.lockout)
			}
			// Return nil so the attempt is committed; failure is reported
			// after the transaction.
			return s.users.SetPINAttempts(ctx, userID, int16(failed), lockedUntil)
		}
		if user.PINFailedCount > 0 || user.PINLockedUntil != nil {
			if err := s.users.SetPINAttempts(ctx, userID, 0, nil); err != nil {
				return err
			}
		}
		if onSuccess != nil {
			return onSuccess(ctx)
		}
		return nil
	})
	if err != nil {
		return err
	}
	return failure
}

// lockUser row-locks the signed-in user. A token for a deleted user is
// treated as unauthenticated.
func (s *PINService) lockUser(ctx context.Context, userID uuid.UUID) (model.User, error) {
	user, err := s.users.GetByIDForUpdate(ctx, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.User{}, model.ErrUnauthorized
	}
	return user, err
}

// validateAndHash checks the PIN rules and hashes the PIN. Hashing is slow on
// purpose, so it runs before any row lock is taken.
func (s *PINService) validateAndHash(field, pin string) (string, error) {
	if err := security.ValidatePIN(field, pin); err != nil {
		return "", err
	}
	return s.hasher.Hash(pin)
}

func (s *PINService) lockedError(remaining time.Duration) error {
	minutes := int(math.Ceil(remaining.Minutes()))
	return model.ErrPINLocked.
		WithDetail("Too many wrong PIN attempts. Try again in %d minutes or reset your PIN.", minutes).
		WithRetryAfter(remaining)
}

// ownsIdentity reports whether a verified Firebase identity is this user's:
// the same Firebase account, or the same phone number.
func ownsIdentity(user model.User, id firebase.Identity) bool {
	if user.FirebaseUID != nil && *user.FirebaseUID == id.UID {
		return true
	}
	phone, err := utils.NormalizePhone("firebase_id_token", id.Phone)
	return err == nil && phone == user.Phone
}
