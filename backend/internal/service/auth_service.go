// Package service holds the business rules. Services run their writes in
// repository transactions and return model errors; they never import Fiber.
package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// refreshTokenBytes is the entropy of a refresh token.
const refreshTokenBytes = 32

// Device describes the device a session is created for.
type Device struct {
	Name     string
	Platform model.DevicePlatform
	FCMToken *string
}

// TokenPair is what a client stores after sign-in or refresh.
type TokenPair struct {
	AccessToken  string
	RefreshToken string
	ExpiresIn    time.Duration // access token lifetime
}

// SignInResult is the outcome of a successful sign-in.
type SignInResult struct {
	Profile   Profile
	Tokens    TokenPair
	IsNewUser bool
}

// AuthService signs users in with a Firebase phone-auth token and manages
// their sessions: refresh-token rotation with reuse detection (FR-AUTH-08)
// and logout.
type AuthService struct {
	tx         *repository.TxManager
	users      *repository.UserRepository
	sessions   *repository.SessionRepository
	members    *repository.MemberRepository
	activity   *Activity
	verifier   firebase.AuthVerifier
	store      storage.Storage
	tokens     *security.TokenIssuer
	clock      clock.Clock
	log        *slog.Logger
	refreshTTL time.Duration
}

func NewAuthService(
	tx *repository.TxManager,
	users *repository.UserRepository,
	sessions *repository.SessionRepository,
	members *repository.MemberRepository,
	activity *Activity,
	verifier firebase.AuthVerifier,
	store storage.Storage,
	tokens *security.TokenIssuer,
	clk clock.Clock,
	log *slog.Logger,
	cfg *config.Config,
) *AuthService {
	return &AuthService{
		tx: tx, users: users, sessions: sessions, members: members, activity: activity, verifier: verifier, store: store,
		tokens: tokens, clock: clk, log: log, refreshTTL: cfg.JWT.RefreshTTL,
	}
}

// SignIn verifies the Firebase ID token, finds or creates the account for its
// phone number, gives it the guest slots added under that number (FR-MEM-04)
// and starts a new session family on device.
func (s *AuthService) SignIn(ctx context.Context, idToken string, device Device) (SignInResult, error) {
	identity, err := s.verifier.Verify(ctx, idToken)
	if err != nil {
		return SignInResult{}, err
	}
	phone, err := utils.NormalizePhone("firebase_id_token", identity.Phone)
	if err != nil {
		return SignInResult{}, model.ErrOTPInvalid.WithDetail("Only Indonesian mobile numbers can sign in.")
	}

	now := s.clock.Now()
	var res SignInResult
	var user model.User
	var sessionID uuid.UUID
	signIn := func(ctx context.Context) error {
		u, isNew, err := s.findOrCreateUser(ctx, identity.UID, phone)
		if err != nil {
			return err
		}
		if err := claimGuestsByPhone(ctx, s.members, s.activity, u.ID, phone); err != nil {
			return err
		}
		sess, refresh, err := s.createSession(ctx, u.ID, uuid.Must(uuid.NewV7()), device, now)
		if err != nil {
			return err
		}
		user = u
		res = SignInResult{IsNewUser: isNew, Tokens: TokenPair{RefreshToken: refresh}}
		sessionID = sess.ID
		return nil
	}
	err = s.tx.WithTx(ctx, signIn)
	if errors.Is(err, repository.ErrDuplicate) {
		// A concurrent first sign-in for the same phone created the user
		// between our lookup and insert, or the user joined a group whose
		// guest we were claiming; this time the lookups see both.
		err = s.tx.WithTx(ctx, signIn)
	}
	if err != nil {
		return SignInResult{}, err
	}

	if res.Tokens, err = s.issue(user.ID, sessionID, res.Tokens.RefreshToken); err != nil {
		return SignInResult{}, err
	}
	if res.Profile, err = profileOf(ctx, s.store, user); err != nil {
		return SignInResult{}, err
	}
	return res, nil
}

// findOrCreateUser looks the user up by Firebase UID, then by phone (linking
// the UID if Firebase issued a new one for a known number), and otherwise
// creates the account with its default settings.
func (s *AuthService) findOrCreateUser(ctx context.Context, uid, phone string) (model.User, bool, error) {
	user, err := s.users.GetByFirebaseUID(ctx, uid)
	if err == nil {
		return user, false, nil
	}
	if !errors.Is(err, repository.ErrNotFound) {
		return model.User{}, false, err
	}

	user, err = s.users.GetByPhone(ctx, phone)
	if err == nil {
		user, err = s.users.SetFirebaseUID(ctx, user.ID, uid)
		return user, false, err
	}
	if !errors.Is(err, repository.ErrNotFound) {
		return model.User{}, false, err
	}

	if user, err = s.users.Create(ctx, uuid.Must(uuid.NewV7()), phone, uid); err != nil {
		return model.User{}, false, err
	}
	if err := s.users.CreateSettings(ctx, user.ID); err != nil {
		return model.User{}, false, err
	}
	return user, true, nil
}

// Refresh rotates a refresh token: the presented session is revoked as
// rotated and a new one in the same family replaces it. Presenting a token
// that was already rotated means it leaked, so the whole family is revoked
// (reuse_detected) and the caller gets refresh_token_invalid.
func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	now := s.clock.Now()
	hash := security.SHA256Hex([]byte(refreshToken))
	var next model.Session
	var nextToken string
	var reused *model.Session

	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		old, err := s.sessions.GetByRefreshTokenHashForUpdate(ctx, hash)
		if errors.Is(err, repository.ErrNotFound) {
			return model.ErrRefreshTokenInvalid
		}
		if err != nil {
			return err
		}
		if old.IsRevoked() {
			if *old.RevokedReason != model.RevokedReasonRotated {
				return model.ErrRefreshTokenInvalid
			}
			// Return nil so the family revocation commits; the error is
			// reported after the transaction.
			reused = &old
			_, err := s.sessions.RevokeFamily(ctx, old.FamilyID, model.RevokedReasonReuseDetected, now)
			return err
		}
		if old.IsExpired(now) {
			return model.ErrRefreshTokenInvalid
		}

		device := Device{Platform: old.DevicePlatform, FCMToken: old.FCMToken}
		if old.DeviceName != nil {
			device.Name = *old.DeviceName
		}
		if next, nextToken, err = s.createSession(ctx, old.UserID, old.FamilyID, device, now); err != nil {
			return err
		}
		return s.sessions.Rotate(ctx, old.ID, next.ID, now)
	})
	if err != nil {
		return TokenPair{}, err
	}
	if reused != nil {
		s.log.WarnContext(ctx, "refresh token reuse detected; session family revoked",
			"user_id", reused.UserID, "family_id", reused.FamilyID, "session_id", reused.ID)
		return TokenPair{}, model.ErrRefreshTokenInvalid
	}
	return s.issue(next.UserID, next.ID, nextToken)
}

// Logout revokes the caller's current session. Revoking one that is already
// revoked is not an error.
func (s *AuthService) Logout(ctx context.Context, userID, sessionID uuid.UUID) error {
	_, err := s.sessions.RevokeForUser(ctx, sessionID, userID, model.RevokedReasonLogout, s.clock.Now())
	return err
}

// ChangePhone moves the account to a new number (FR-AUTH-06). oldToken must
// come from an OTP to the current number and newToken from an OTP to the new
// one; a number that already has an account is phone_already_registered.
// Every session except sessionID is signed out.
func (s *AuthService) ChangePhone(ctx context.Context, userID, sessionID uuid.UUID, oldToken, newToken string) (Profile, error) {
	oldID, err := s.verifier.Verify(ctx, oldToken)
	if err != nil {
		return Profile{}, err
	}
	newID, err := s.verifier.Verify(ctx, newToken)
	if err != nil {
		return Profile{}, err
	}
	newPhone, err := utils.NormalizePhone("new_firebase_id_token", newID.Phone)
	if err != nil {
		return Profile{}, model.ErrOTPInvalid.WithDetail("Only Indonesian mobile numbers can be used.")
	}

	var user model.User
	err = s.tx.WithTx(ctx, func(ctx context.Context) error {
		current, err := currentUser(s.users.GetByIDForUpdate(ctx, userID))
		if err != nil {
			return err
		}
		if !ownsIdentity(current, oldID) {
			return model.ErrOTPInvalid.WithDetail("The first OTP was not sent to this account's phone number.")
		}
		if newPhone == current.Phone {
			return model.NewValidationError(model.FieldError{
				Field: "new_firebase_id_token", Code: model.FieldInvalidFormat,
				Message: "The new number is the same as the current one.",
			})
		}
		if _, err := s.users.GetByPhone(ctx, newPhone); err == nil {
			return model.ErrPhoneAlreadyRegistered
		} else if !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		if user, err = s.users.UpdatePhone(ctx, userID, newPhone, newID.UID); err != nil {
			return err
		}
		_, err = s.sessions.RevokeOthers(ctx, userID, sessionID, model.RevokedReasonPhoneChanged, s.clock.Now())
		return err
	})
	if errors.Is(err, repository.ErrDuplicate) {
		// The number or its Firebase account was claimed after our lookup.
		return Profile{}, model.ErrPhoneAlreadyRegistered
	}
	if err != nil {
		return Profile{}, err
	}
	return profileOf(ctx, s.store, user)
}

// createSession inserts a session with a fresh refresh token and returns the
// token; only its hash is stored.
func (s *AuthService) createSession(ctx context.Context, userID, familyID uuid.UUID, device Device, now time.Time) (model.Session, string, error) {
	token, err := security.RandomToken(refreshTokenBytes)
	if err != nil {
		return model.Session{}, "", err
	}
	sess := model.Session{
		ID:               uuid.Must(uuid.NewV7()),
		UserID:           userID,
		FamilyID:         familyID,
		RefreshTokenHash: security.SHA256Hex([]byte(token)),
		DevicePlatform:   device.Platform,
		FCMToken:         device.FCMToken,
		ExpiresAt:        now.Add(s.refreshTTL),
	}
	if device.Name != "" {
		sess.DeviceName = &device.Name
	}
	created, err := s.sessions.Create(ctx, sess, now)
	if err != nil {
		return model.Session{}, "", fmt.Errorf("create session: %w", err)
	}
	return created, token, nil
}

// issue signs the access token that goes with refreshToken.
func (s *AuthService) issue(userID, sessionID uuid.UUID, refreshToken string) (TokenPair, error) {
	access, _, err := s.tokens.Issue(userID, sessionID)
	if err != nil {
		return TokenPair{}, err
	}
	return TokenPair{AccessToken: access, RefreshToken: refreshToken, ExpiresIn: s.tokens.TTL()}, nil
}
