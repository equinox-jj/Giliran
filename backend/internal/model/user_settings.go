package model

import (
	"time"

	"github.com/google/uuid"
)

// Language is the app language stored in user_settings.language.
type Language string

const (
	LanguageIndonesian Language = "id"
	LanguageEnglish    Language = "en"
	// DefaultLanguage is the language a new account starts with.
	DefaultLanguage = LanguageIndonesian
)

// IsValid reports whether l is a supported language (the CHECK constraint).
func (l Language) IsValid() bool {
	switch l {
	case LanguageIndonesian, LanguageEnglish:
		return true
	}
	return false
}

// UserSettings holds one user's language and notification preferences,
// mirroring the user_settings table (DB_SCHEME §3.2). Each user has one row.
type UserSettings struct {
	UserID                 uuid.UUID `db:"user_id"`
	Language               Language  `db:"language"`
	NotifyPaymentReminders bool      `db:"notify_payment_reminders"`
	NotifyDrawResults      bool      `db:"notify_draw_results"`
	NotifyGroupActivity    bool      `db:"notify_group_activity"`
	UpdatedAt              time.Time `db:"updated_at"`
}

// TableName is the PostgreSQL table that stores user settings.
func (UserSettings) TableName() string {
	return "user_settings"
}

// NewUserSettings returns the defaults the table applies (Indonesian, every
// notification on), for creating the row alongside a new user.
func NewUserSettings(userID uuid.UUID) UserSettings {
	return UserSettings{
		UserID:                 userID,
		Language:               DefaultLanguage,
		NotifyPaymentReminders: true,
		NotifyDrawResults:      true,
		NotifyGroupActivity:    true,
	}
}
