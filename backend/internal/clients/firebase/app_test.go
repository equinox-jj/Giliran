package firebase

import (
	"testing"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

func TestNewAppMissingCredentials(t *testing.T) {
	// Arrange
	cfg := config.Firebase{CredentialsFile: t.TempDir() + "/missing.json"}

	// Act
	_, err := NewApp(t.Context(), cfg)

	// Assert
	if err == nil {
		t.Error("got nil error, want missing credentials file")
	}
}
