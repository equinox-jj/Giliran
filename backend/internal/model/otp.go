package model

import (
	"net/netip"
	"time"

	"github.com/google/uuid"
)

const (
	// OTPCodeLength is the number of digits in an email code.
	OTPCodeLength = 6
	// OTPMaxAttempts is how many wrong codes lock a request. The table's
	// CHECK constraints fix it, so it is not configurable.
	OTPMaxAttempts = 5
	// OTPMaxResends is how many times one request can send a new code, also
	// fixed by a CHECK constraint.
	OTPMaxResends = 5
)

// OTPPurpose is what an email code authorizes, stored in
// email_otp_requests.purpose.
type OTPPurpose string

const (
	OTPPurposeSignIn      OTPPurpose = "sign_in"
	OTPPurposeResetPIN    OTPPurpose = "reset_pin"
	OTPPurposeChangeEmail OTPPurpose = "change_email"
)

// IsValid reports whether p is a known purpose (the CHECK constraint).
func (p OTPPurpose) IsValid() bool {
	switch p {
	case OTPPurposeSignIn, OTPPurposeResetPIN, OTPPurposeChangeEmail:
		return true
	}
	return false
}

// OTPStatus is a request's state (DB_SCHEME §4.4), stored in
// email_otp_requests.status.
type OTPStatus string

const (
	OTPStatusPending   OTPStatus = "pending"
	OTPStatusConsumed  OTPStatus = "consumed"
	OTPStatusExpired   OTPStatus = "expired"
	OTPStatusLocked    OTPStatus = "locked"
	OTPStatusCancelled OTPStatus = "cancelled"
)

// IsValid reports whether s is a known request status (the CHECK constraint).
func (s OTPStatus) IsValid() bool {
	switch s {
	case OTPStatusPending, OTPStatusConsumed, OTPStatusExpired, OTPStatusLocked, OTPStatusCancelled:
		return true
	}
	return false
}

// OTPSendStatus is how delivery of the latest code went, stored in
// email_otp_requests.send_status.
type OTPSendStatus string

const (
	OTPSendStatusQueued OTPSendStatus = "queued"
	OTPSendStatusSent   OTPSendStatus = "sent"
	OTPSendStatusFailed OTPSendStatus = "failed"
	// OTPSendStatusSkipped marks a reset_pin request for an unknown email:
	// nothing is sent, but the API answers as if it were.
	OTPSendStatusSkipped OTPSendStatus = "skipped"
)

// IsValid reports whether s is a known send status (the CHECK constraint).
func (s OTPSendStatus) IsValid() bool {
	switch s {
	case OTPSendStatusQueued, OTPSendStatusSent, OTPSendStatusFailed, OTPSendStatusSkipped:
		return true
	}
	return false
}

// OTPRequest is one email code request, mirroring the email_otp_requests
// table (DB_SCHEME §3.16). The code itself is never stored, only its HMAC.
type OTPRequest struct {
	ID                uuid.UUID      `db:"id"` // returned to the app as otp_id
	Purpose           OTPPurpose     `db:"purpose"`
	Email             string         `db:"email"`   // lowercase; the new address for change_email
	UserID            *uuid.UUID     `db:"user_id"` // set at creation for reset_pin and change_email, on completion for sign_in
	CodeHash          string         `db:"code_hash"`
	Attempts          int16          `db:"attempts"`
	ResendCount       int16          `db:"resend_count"`
	LastSentAt        time.Time      `db:"last_sent_at"`
	SendStatus        OTPSendStatus  `db:"send_status"`
	ProviderMessageID *string        `db:"provider_message_id"`
	DeviceName        *string        `db:"device_name"`
	DevicePlatform    DevicePlatform `db:"device_platform"`
	FCMToken          *string        `db:"fcm_token"`
	RequesterIP       *netip.Addr    `db:"requester_ip"`
	Status            OTPStatus      `db:"status"`
	ExpiresAt         time.Time      `db:"expires_at"`
	ConsumedAt        *time.Time     `db:"consumed_at"`
	CreatedAt         time.Time      `db:"created_at"`
}

// IsPending reports whether the request can still be verified or resent,
// ignoring expiry (see IsExpired).
func (r *OTPRequest) IsPending() bool {
	return r.Status == OTPStatusPending
}

// IsExpired reports whether the latest code is past its expiry at now, even
// if the expiry job has not marked the row yet.
func (r *OTPRequest) IsExpired(now time.Time) bool {
	return !now.Before(r.ExpiresAt)
}

// AttemptsRemaining is how many wrong codes the request still accepts.
func (r *OTPRequest) AttemptsRemaining() int {
	return max(OTPMaxAttempts-int(r.Attempts), 0)
}

// ResendAvailableAt is when a new code may be requested, interval after the
// latest send.
func (r *OTPRequest) ResendAvailableAt(interval time.Duration) time.Time {
	return r.LastSentAt.Add(interval)
}
