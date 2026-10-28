package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

// EmailOtpRequest is the body of POST /auth/email/otp. The service
// normalizes the email; pin is checked as a PIN, not format-checked, for
// change_email.
type EmailOtpRequest struct {
	Purpose        string  `json:"purpose" validate:"required,oneof=sign_in reset_pin change_email"`
	Email          string  `json:"email" validate:"required,email,max=254"`
	DeviceName     string  `json:"device_name" validate:"required,max=100"`
	DevicePlatform string  `json:"device_platform" validate:"required,oneof=android ios"`
	FCMToken       *string `json:"fcm_token" validate:"omitnil,max=4096"`
	PIN            *string `json:"pin"`
}

// EmailOtpChallenge is the EmailOtpChallenge schema.
type EmailOtpChallenge struct {
	ID                uuid.UUID        `json:"id"`
	Purpose           model.OTPPurpose `json:"purpose"`
	EmailMasked       string           `json:"email_masked"`
	CodeLength        int              `json:"code_length"`
	ExpiresAt         time.Time        `json:"expires_at"`
	ResendAvailableAt time.Time        `json:"resend_available_at"`
	AttemptsRemaining int              `json:"attempts_remaining"`
}

func NewEmailOtpChallenge(ch service.OTPChallenge) EmailOtpChallenge {
	return EmailOtpChallenge{
		ID:                ch.ID,
		Purpose:           ch.Purpose,
		EmailMasked:       ch.EmailMasked,
		CodeLength:        security.OTPCodeLength,
		ExpiresAt:         ch.ExpiresAt,
		ResendAvailableAt: ch.ResendAvailableAt,
		AttemptsRemaining: ch.AttemptsRemaining,
	}
}

// EmailOtpVerifyRequest is the body of POST /auth/email/otp/{otp_id}/verify.
// Which PIN fields are needed depends on the request's purpose, so the
// service checks them.
type EmailOtpVerifyRequest struct {
	Code               string  `json:"code" validate:"required,len=6,number"`
	PIN                *string `json:"pin"`
	NewPIN             *string `json:"new_pin"`
	NewPINConfirmation *string `json:"new_pin_confirmation"`
}

// EmailOtpResult is the EmailOtpResult schema: Auth for sign_in and
// reset_pin, User for change_email, the other one null.
type EmailOtpResult struct {
	Purpose model.OTPPurpose `json:"purpose"`
	Auth    *AuthResult      `json:"auth"`
	User    *Me              `json:"user"`
}

func NewEmailOtpResult(r service.OTPResult) EmailOtpResult {
	out := EmailOtpResult{Purpose: r.Purpose}
	if r.Auth != nil {
		a := NewAuthResult(*r.Auth)
		out.Auth = &a
	}
	if r.User != nil {
		me := NewMe(r.User.User, r.User.AvatarURL)
		out.User = &me
	}
	return out
}

// RefreshRequest is the body of POST /auth/refresh.
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

// TokenPair is the TokenPair schema.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int64  `json:"expires_in"` // seconds
}

// NewTokenPair builds a Bearer token pair; expiresIn is the access token
// lifetime.
func NewTokenPair(access, refresh string, expiresIn time.Duration) TokenPair {
	return TokenPair{AccessToken: access, RefreshToken: refresh, TokenType: "Bearer", ExpiresIn: int64(expiresIn / time.Second)}
}

// Me is the Me schema: the signed-in user's own profile.
type Me struct {
	ID        uuid.UUID `json:"id"`
	Email     string    `json:"email"`
	Phone     *string   `json:"phone"`
	Name      *string   `json:"name"`
	AvatarURL *string   `json:"avatar_url"`
	PINSet    bool      `json:"pin_set"`
	CreatedAt time.Time `json:"created_at"`
}

// NewMe maps a user to Me. avatarURL is a presigned URL, or nil.
func NewMe(u model.User, avatarURL *string) Me {
	var email string
	if u.Email != nil { // only a deleted account has none, and it cannot sign in
		email = *u.Email
	}
	return Me{ID: u.ID, Email: email, Phone: u.Phone, Name: u.Name, AvatarURL: avatarURL, PINSet: u.HasPIN(), CreatedAt: u.CreatedAt}
}

// AuthResult is the AuthResult schema, returned by sign-in and PIN reset.
type AuthResult struct {
	User      Me        `json:"user"`
	Tokens    TokenPair `json:"tokens"`
	IsNewUser bool      `json:"is_new_user"`
	PINSet    bool      `json:"pin_set"`
}

func NewAuthResult(r service.SignInResult) AuthResult {
	return AuthResult{
		User:      NewMe(r.Profile.User, r.Profile.AvatarURL),
		Tokens:    NewTokenPair(r.Tokens.AccessToken, r.Tokens.RefreshToken, r.Tokens.ExpiresIn),
		IsNewUser: r.IsNewUser,
		PINSet:    r.Profile.User.HasPIN(),
	}
}

// PinRequest is the body of POST /auth/pin/verify. The PIN is not
// format-checked: anything that is not the PIN is simply wrong.
type PinRequest struct {
	PIN string `json:"pin"`
}

// SetPinRequest is the body of POST /auth/pin. Strength rules are checked by
// the service (pin_too_weak).
type SetPinRequest struct {
	PIN             string `json:"pin" validate:"required"`
	PINConfirmation string `json:"pin_confirmation" validate:"required,eqfield=PIN"`
}

// ChangePinRequest is the body of PUT /auth/pin.
type ChangePinRequest struct {
	CurrentPIN         string `json:"current_pin" validate:"required"`
	NewPIN             string `json:"new_pin" validate:"required"`
	NewPINConfirmation string `json:"new_pin_confirmation" validate:"required,eqfield=NewPIN"`
}
