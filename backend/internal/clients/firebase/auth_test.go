package firebase

import (
	"errors"
	"testing"

	"firebase.google.com/go/v4/auth"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

func TestIdentityFrom(t *testing.T) {
	// Arrange
	tests := []struct {
		name    string
		token   *auth.Token
		want    Identity
		wantErr error
	}{
		{"phone token", &auth.Token{UID: "uid-1", Claims: map[string]any{"phone_number": "+6281234567890"}}, Identity{UID: "uid-1", Phone: "+6281234567890"}, nil},
		{"no phone", &auth.Token{UID: "uid-1", Claims: map[string]any{"email": "a@b.c"}}, Identity{}, model.ErrOTPInvalid},
		{"phone not a string", &auth.Token{UID: "uid-1", Claims: map[string]any{"phone_number": 62}}, Identity{}, model.ErrOTPInvalid},
		{"no uid", &auth.Token{Claims: map[string]any{"phone_number": "+6281234567890"}}, Identity{}, model.ErrOTPInvalid},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := identityFrom(tt.token)

			// Assert
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("got %+v, want %+v", got, tt.want)
			}
		})
	}
}

func TestNewVerifierMissingCredentials(t *testing.T) {
	// Arrange
	cfg := config.Firebase{CredentialsFile: t.TempDir() + "/missing.json"}

	// Act
	_, err := NewVerifier(t.Context(), cfg)

	// Assert
	if err == nil {
		t.Error("got nil error, want missing credentials file")
	}
}
