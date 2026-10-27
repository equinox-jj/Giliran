//go:build integration

package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

const (
	goodPIN  = "135792"
	otherPIN = "246813"
	wrongPIN = "975310"
)

// pinCfg uses tiny argon2 parameters so the tests stay fast.
var pinCfg = &config.Config{PIN: config.PIN{
	Argon2MemoryKiB: 64, Argon2Iterations: 1, Argon2Parallelism: 1, Argon2SaltLength: 16, Argon2KeyLength: 32,
	MaxAttempts: 5, LockoutDuration: 15 * time.Minute,
}}

type pinEnv struct {
	authEnv
	userID    uuid.UUID
	sessionID uuid.UUID
}

// newPINEnv signs Rina in under the "tok" key.
func newPINEnv(t *testing.T) pinEnv {
	t.Helper()
	env := newAuthEnv(t, accounts{"tok": rina})
	res := env.signIn(t, "tok")
	c := env.caller(t, res)
	return pinEnv{authEnv: env, userID: c.UserID, sessionID: c.SessionID}
}

func (e pinEnv) setPIN(t *testing.T) {
	t.Helper()
	if err := e.pins.Set(context.Background(), e.userID, goodPIN); err != nil {
		t.Fatalf("Set: %v", err)
	}
}

// failVerify enters the wrong PIN n times.
func (e pinEnv) failVerify(t *testing.T, n int) {
	t.Helper()
	for i := range n {
		if err := e.pins.Verify(context.Background(), e.userID, wrongPIN); !errors.Is(err, model.ErrPINInvalid) && !errors.Is(err, model.ErrPINLocked) {
			t.Fatalf("wrong attempt %d: %v", i+1, err)
		}
	}
}

// attempts returns the stored failed count and whether a lock is set.
func (e pinEnv) attempts(t *testing.T) (int, bool) {
	t.Helper()
	var failed int
	var locked *time.Time
	if err := e.pool.QueryRow(context.Background(),
		`SELECT pin_failed_count, pin_locked_until FROM users WHERE id = $1`, e.userID).Scan(&failed, &locked); err != nil {
		t.Fatalf("attempts: %v", err)
	}
	return failed, locked != nil
}

func TestPINSetThenVerify(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, goodPIN)

	// Assert
	if err != nil {
		t.Errorf("Verify: %v", err)
	}
}

func TestPINSetErrors(t *testing.T) {
	// Arrange
	t.Parallel()
	tests := []struct {
		name    string
		setup   func(t *testing.T, env pinEnv)
		pin     string
		wantErr error
	}{
		{"already set", func(t *testing.T, env pinEnv) { env.setPIN(t) }, otherPIN, model.ErrPINAlreadySet},
		{"weak PIN", func(*testing.T, pinEnv) {}, "123456", model.ErrValidation},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			t.Parallel()
			env := newPINEnv(t)
			tt.setup(t, env)

			// Act
			err := env.pins.Set(context.Background(), env.userID, tt.pin)

			// Assert
			if !errors.Is(err, tt.wantErr) {
				t.Errorf("got %v, want %v", err, tt.wantErr)
			}
		})
	}
}

func TestPINVerifyNotSet(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, goodPIN)

	// Assert
	if !errors.Is(err, model.ErrPINNotSet) {
		t.Errorf("got %v, want pin_not_set", err)
	}
}

func TestPINWrongAttemptIsCounted(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, wrongPIN)

	// Assert
	if !errors.Is(err, model.ErrPINInvalid) {
		t.Fatalf("got %v, want pin_invalid", err)
	}
	if failed, locked := env.attempts(t); failed != 1 || locked {
		t.Errorf("failed %d locked %v, want 1 false", failed, locked)
	}
}

func TestPINFifthWrongAttemptLocks(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)
	env.failVerify(t, 4)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, wrongPIN)

	// Assert
	var me *model.Error
	if !errors.As(err, &me) || me.Code != "pin_locked" || me.RetryAfter != 15*time.Minute {
		t.Fatalf("got %v (retry after %v), want pin_locked for 15m", err, me)
	}
	if failed, locked := env.attempts(t); failed != 0 || !locked {
		t.Errorf("failed %d locked %v, want 0 true", failed, locked)
	}
}

func TestPINLockedRejectsCorrectPIN(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)
	env.failVerify(t, 5)
	env.clock.Advance(10 * time.Minute)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, goodPIN)

	// Assert
	var me *model.Error
	if !errors.As(err, &me) || me.Code != "pin_locked" || me.RetryAfter != 5*time.Minute {
		t.Errorf("got %v, want pin_locked with 5m left", err)
	}
}

func TestPINUnlocksAfterLockout(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)
	env.failVerify(t, 5)
	env.clock.Advance(15 * time.Minute)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, goodPIN)

	// Assert
	if err != nil {
		t.Fatalf("Verify after lockout: %v", err)
	}
	if failed, locked := env.attempts(t); failed != 0 || locked {
		t.Errorf("failed %d locked %v, want cleared", failed, locked)
	}
}

func TestPINCorrectAttemptClearsCount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)
	env.failVerify(t, 3)

	// Act
	err := env.pins.Verify(context.Background(), env.userID, goodPIN)

	// Assert
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if failed, _ := env.attempts(t); failed != 0 {
		t.Errorf("failed %d, want 0", failed)
	}
}

func TestPINConcurrentWrongAttemptsAllCount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)
	var wg sync.WaitGroup

	// Act
	for range 4 {
		wg.Go(func() { _ = env.pins.Verify(context.Background(), env.userID, wrongPIN) })
	}
	wg.Wait()

	// Assert
	if failed, _ := env.attempts(t); failed != 4 {
		t.Errorf("failed %d, want 4 (no lost updates)", failed)
	}
}

func TestPINChange(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)
	if err := env.pins.Change(context.Background(), env.userID, goodPIN, otherPIN); err != nil {
		t.Fatalf("Change: %v", err)
	}

	// Act
	err := env.pins.Verify(context.Background(), env.userID, otherPIN)

	// Assert
	if err != nil {
		t.Errorf("new PIN rejected: %v", err)
	}
}

func TestPINChangeWrongCurrent(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPINEnv(t)
	env.setPIN(t)

	// Act
	err := env.pins.Change(context.Background(), env.userID, wrongPIN, otherPIN)

	// Assert
	if !errors.Is(err, model.ErrPINInvalid) {
		t.Fatalf("got %v, want pin_invalid", err)
	}
	if verr := env.pins.Verify(context.Background(), env.userID, goodPIN); verr != nil {
		t.Errorf("old PIN no longer works: %v", verr)
	}
	if failed, _ := env.attempts(t); failed != 0 {
		t.Errorf("failed %d after the successful verify, want 0", failed)
	}
}
