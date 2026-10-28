// Package firebase sends push notifications through FCM with the Firebase
// Admin SDK. Only the worker uses it; sign-in is by email code, so the API
// needs no Firebase credentials.
package firebase

import (
	"context"
	"fmt"
	"os"

	fb "firebase.google.com/go/v4"
	"google.golang.org/api/option"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// NewApp builds the Admin SDK app from FIREBASE_CREDENTIALS_FILE (a
// service-account JSON) and, if set, FIREBASE_PROJECT_ID. It fails when the
// credentials file is missing, so the worker does not start without it.
func NewApp(ctx context.Context, cfg config.Firebase) (*fb.App, error) {
	if _, err := os.Stat(cfg.CredentialsFile); err != nil {
		return nil, fmt.Errorf("FIREBASE_CREDENTIALS_FILE %q: %w (download a service-account key from the Firebase console)", cfg.CredentialsFile, err)
	}
	var fc *fb.Config
	if cfg.ProjectID != "" {
		fc = &fb.Config{ProjectID: cfg.ProjectID}
	}
	app, err := fb.NewApp(ctx, fc, option.WithAuthCredentialsFile(option.ServiceAccount, cfg.CredentialsFile))
	if err != nil {
		return nil, fmt.Errorf("firebase app: %w", err)
	}
	return app, nil
}
