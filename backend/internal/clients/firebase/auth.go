// Package firebase verifies Firebase phone-auth ID tokens with the Firebase
// Admin SDK. The app does the OTP with Firebase; the backend only checks the
// resulting token and then issues its own tokens. It also deletes the
// Firebase user when an account is deleted, and sends push notifications
// through FCM.
package firebase

import (
	"context"
	"fmt"

	fb "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// Identity is who a verified ID token belongs to.
type Identity struct {
	UID   string // Firebase user ID
	Phone string // E.164, as Firebase reports it
}

// AuthVerifier checks a Firebase ID token. Services depend on this interface
// so tests can use a fake.
type AuthVerifier interface {
	// Verify returns model.ErrOTPInvalid for a token that is invalid, expired,
	// revoked or carries no phone number.
	Verify(ctx context.Context, idToken string) (Identity, error)
}

// UserDeleter removes a Firebase user, so a deleted account leaves no phone
// number behind in Firebase Auth.
type UserDeleter interface {
	// DeleteUser deletes the user with uid. A user that does not exist is
	// not an error.
	DeleteUser(ctx context.Context, uid string) error
}

// Verifier is the Firebase Admin SDK implementation of AuthVerifier and
// UserDeleter.
type Verifier struct {
	client *auth.Client
}

// NewVerifier builds the Auth client from app.
func NewVerifier(ctx context.Context, app *fb.App) (*Verifier, error) {
	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase auth client: %w", err)
	}
	return &Verifier{client: client}, nil
}

func (v *Verifier) Verify(ctx context.Context, idToken string) (Identity, error) {
	token, err := v.client.VerifyIDToken(ctx, idToken)
	if err != nil {
		if auth.IsIDTokenInvalid(err) || auth.IsIDTokenExpired(err) {
			return Identity{}, model.ErrOTPInvalid
		}
		// Anything else (fetching Google's public keys, for one) is our
		// problem, not the client's.
		return Identity{}, fmt.Errorf("verify firebase id token: %w", err)
	}
	return identityFrom(token)
}

// identityFrom extracts the identity from a verified token. Only phone sign-in
// is supported, so a token without a phone number is rejected.
func identityFrom(token *auth.Token) (Identity, error) {
	phone, _ := token.Claims["phone_number"].(string)
	if phone == "" || token.UID == "" {
		return Identity{}, model.ErrOTPInvalid.WithDetail("The Firebase ID token has no phone number.")
	}
	return Identity{UID: token.UID, Phone: phone}, nil
}

func (v *Verifier) DeleteUser(ctx context.Context, uid string) error {
	if err := v.client.DeleteUser(ctx, uid); err != nil && !auth.IsUserNotFound(err) {
		return fmt.Errorf("delete firebase user: %w", err)
	}
	return nil
}

var (
	_ AuthVerifier = (*Verifier)(nil)
	_ UserDeleter  = (*Verifier)(nil)
)
