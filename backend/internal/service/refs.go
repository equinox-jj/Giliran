package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

// UserRef is another user as group members see them (UserSummary).
type UserRef struct {
	ID        uuid.UUID
	Name      string
	AvatarURL *string
}

// refs builds the user and member references that group responses embed.
type refs struct {
	users *repository.UserRepository
	store storage.Storage
}

// user returns the reference for userID. A deleted account shows as
// model.DeletedUserName.
func (r refs) user(ctx context.Context, userID uuid.UUID) (UserRef, error) {
	u, err := r.users.GetByID(ctx, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return UserRef{ID: userID, Name: model.DeletedUserName}, nil
	}
	if err != nil {
		return UserRef{}, err
	}
	url, err := r.presign(ctx, u.AvatarKey)
	if err != nil {
		return UserRef{}, err
	}
	return UserRef{ID: u.ID, Name: u.DisplayName(), AvatarURL: url}, nil
}

// presign returns a URL for key, or nil when there is no object.
func (r refs) presign(ctx context.Context, key *string) (*string, error) {
	if key == nil {
		return nil, nil
	}
	u, err := r.store.PresignGet(ctx, *key)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// members presigns the avatars of views. guestPhones keeps guest phone
// numbers, which only organizers and co-organizers may see.
func (r refs) members(ctx context.Context, views []repository.MemberView, guestPhones bool) ([]Member, error) {
	out := make([]Member, len(views))
	for i, v := range views {
		m, err := r.member(ctx, v, guestPhones)
		if err != nil {
			return nil, err
		}
		out[i] = m
	}
	return out, nil
}

func (r refs) member(ctx context.Context, v repository.MemberView, guestPhones bool) (Member, error) {
	if !guestPhones {
		v.Member.GuestPhone = nil
	}
	url, err := r.presign(ctx, v.UserAvatarKey)
	if err != nil {
		return Member{}, err
	}
	return Member{MemberView: v, AvatarURL: url}, nil
}

// trimmedLength trims s and checks it has min to max characters, reporting a
// failure on field.
func trimmedLength(field, s string, minLen, maxLen int) (string, error) {
	s = strings.TrimSpace(s)
	switch n := utf8.RuneCountInString(s); {
	case n < minLen:
		return "", model.NewValidationError(model.FieldError{
			Field: field, Code: model.FieldMinLength, Message: fmt.Sprintf("Must have at least %d characters.", minLen),
		})
	case n > maxLen:
		return "", model.NewValidationError(model.FieldError{
			Field: field, Code: model.FieldMaxLength, Message: fmt.Sprintf("Must have at most %d characters.", maxLen),
		})
	}
	return s, nil
}
