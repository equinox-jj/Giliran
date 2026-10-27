package service

import (
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

// PINService manages the app PIN (FR-AUTH-02..04): set once, verify to
// unlock, and change with the current PIN. Resetting a forgotten PIN goes
// through an email code (OTPService). Wrong PINs are counted on the user
// row; PIN_MAX_ATTEMPTS failures lock PIN entry for PIN_LOCKOUT_DURATION.
type PINService struct {
	tx          *repository.TxManager
	users       *repository.UserRepository
	hasher      *security.PINHasher
	clock       clock.Clock
	maxAttempts int
	lockout     time.Duration
}

func NewPINService(
	tx *repository.TxManager,
	users *repository.UserRepository,
	hasher *security.PINHasher,
	clk clock.Clock,
	cfg *config.Config,
) *PINService {
	return &PINService{
		tx: tx, users: users, hasher: hasher, clock: clk,
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

// checkPIN verifies pin under a row lock and runs onSuccess in the same
// transaction when it matches. A wrong PIN is recorded and committed before
// pin_invalid or pin_locked is returned.
func (s *PINService) checkPIN(ctx context.Context, userID uuid.UUID, pin string, onSuccess func(context.Context) error) error {
	var failure error
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		failure = nil
		user, err := s.lockUser(ctx, userID)
		if err != nil {
			return err
		}
		if failure, err = s.attemptPIN(ctx, user, pin); err != nil || failure != nil {
			return err
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

// attemptPIN checks pin for user, which the caller has row-locked inside its
// transaction. A wrong PIN is counted, and failure (pin_invalid or
// pin_locked) is returned with a nil err, so the caller commits the count
// and reports failure afterwards. A match clears the count.
func (s *PINService) attemptPIN(ctx context.Context, user model.User, pin string) (failure, err error) {
	now := s.clock.Now()
	if !user.HasPIN() {
		return nil, model.ErrPINNotSet
	}
	if user.IsPINLocked(now) {
		return s.lockedError(user.PINLockedUntil.Sub(now)), nil
	}
	ok, err := s.hasher.Verify(pin, *user.PINHash)
	if err != nil {
		return nil, fmt.Errorf("verify pin: %w", err)
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
		return failure, s.users.SetPINAttempts(ctx, user.ID, int16(failed), lockedUntil)
	}
	if user.PINFailedCount > 0 || user.PINLockedUntil != nil {
		return nil, s.users.SetPINAttempts(ctx, user.ID, 0, nil)
	}
	return nil, nil
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
