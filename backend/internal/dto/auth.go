package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// SignInRequest is the body of POST /auth/sign-in.
type SignInRequest struct {
	FirebaseIDToken string  `json:"firebase_id_token" validate:"required"`
	DeviceName      string  `json:"device_name" validate:"required,max=100"`
	DevicePlatform  string  `json:"device_platform" validate:"required,oneof=android ios"`
	FCMToken        *string `json:"fcm_token"`
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
	Phone     string    `json:"phone"`
	Name      *string   `json:"name"`
	AvatarURL *string   `json:"avatar_url"`
	PINSet    bool      `json:"pin_set"`
	CreatedAt time.Time `json:"created_at"`
}

// NewMe maps a user to Me. avatarURL is a presigned URL, or nil.
func NewMe(u model.User, avatarURL *string) Me {
	return Me{ID: u.ID, Phone: u.Phone, Name: u.Name, AvatarURL: avatarURL, PINSet: u.HasPIN(), CreatedAt: u.CreatedAt}
}

// AuthResult is the AuthResult schema, returned by sign-in.
type AuthResult struct {
	User      Me        `json:"user"`
	Tokens    TokenPair `json:"tokens"`
	IsNewUser bool      `json:"is_new_user"`
	PINSet    bool      `json:"pin_set"`
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

// ResetPinRequest is the body of POST /auth/pin/reset.
type ResetPinRequest struct {
	FirebaseIDToken    string `json:"firebase_id_token" validate:"required"`
	NewPIN             string `json:"new_pin" validate:"required"`
	NewPINConfirmation string `json:"new_pin_confirmation" validate:"required,eqfield=NewPIN"`
}
