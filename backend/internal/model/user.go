package model

import (
	"time"

	"github.com/google/uuid"
)

const (
	// MaxPINFailedAttempts is how many wrong PINs lock PIN entry (FR-AUTH-03).
	MaxPINFailedAttempts = 5
	// PINLockDuration is how long PIN entry stays locked after too many failures.
	PINLockDuration = 15 * time.Minute
	// DeletedUserName replaces the name of a soft-deleted user in history.
	DeletedUserName = "Mantan anggota"
)

// User is one account, mirroring the users table (DB_SCHEME §3.1).
// The email, proven by an email OTP, is the identity and is unique among
// active users. Email and EmailVerifiedAt are nil only on deleted users.
type User struct {
	ID              uuid.UUID  `db:"id"`
	Email           *string    `db:"email"`             // lowercase
	EmailVerifiedAt *time.Time `db:"email_verified_at"` // last time the email was proven
	Phone           *string    `db:"phone"`             // optional, unverified, E.164 +62…; only for wa.me reminder links
	Name            *string    `db:"name"`              // 2–50 chars; nil until set after first sign-in
	AvatarKey       *string    `db:"avatar_key"`        // MinIO object key
	PINHash         *string    `db:"pin_hash"`          // argon2id encoded hash; nil until the PIN is set
	PINFailedCount  int16      `db:"pin_failed_count"`
	PINLockedUntil  *time.Time `db:"pin_locked_until"`
	CreatedAt       time.Time  `db:"created_at"`
	UpdatedAt       time.Time  `db:"updated_at"`
	DeletedAt       *time.Time `db:"deleted_at"`
}

// IsDeleted reports whether the account has been soft-deleted.
func (u *User) IsDeleted() bool {
	return u.DeletedAt != nil
}

// HasPIN reports whether the user has set an app PIN.
func (u *User) HasPIN() bool {
	return u.PINHash != nil
}

// IsPINLocked reports whether PIN entry is locked at the given time.
func (u *User) IsPINLocked(now time.Time) bool {
	return u.PINLockedUntil != nil && now.Before(*u.PINLockedUntil)
}

// DisplayName returns the name shown to other members: the anonymized
// placeholder for deleted accounts, or an empty string if no name is set yet.
func (u *User) DisplayName() string {
	if u.IsDeleted() {
		return DeletedUserName
	}
	if u.Name == nil {
		return ""
	}
	return *u.Name
}
