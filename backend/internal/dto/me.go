package dto

import (
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// UpdateMeRequest is the body of PATCH /me. The service trims the name and
// checks its length again.
type UpdateMeRequest struct {
	Name string `json:"name" validate:"required,min=2,max=50"`
}

// ChangePhoneRequest is the body of PUT /auth/phone.
type ChangePhoneRequest struct {
	OldFirebaseIDToken string `json:"old_firebase_id_token" validate:"required"`
	NewFirebaseIDToken string `json:"new_firebase_id_token" validate:"required"`
}

// UserSettings is the UserSettings schema.
type UserSettings struct {
	Language               model.Language `json:"language"`
	NotifyPaymentReminders bool           `json:"notify_payment_reminders"`
	NotifyDrawResults      bool           `json:"notify_draw_results"`
	NotifyGroupActivity    bool           `json:"notify_group_activity"`
}

func NewUserSettings(s model.UserSettings) UserSettings {
	return UserSettings{
		Language:               s.Language,
		NotifyPaymentReminders: s.NotifyPaymentReminders,
		NotifyDrawResults:      s.NotifyDrawResults,
		NotifyGroupActivity:    s.NotifyGroupActivity,
	}
}

// UpdateSettingsRequest is the body of PATCH /me/settings. Absent fields keep
// their value; at least one must be present.
type UpdateSettingsRequest struct {
	Language               *string `json:"language" validate:"omitnil,oneof=id en"`
	NotifyPaymentReminders *bool   `json:"notify_payment_reminders"`
	NotifyDrawResults      *bool   `json:"notify_draw_results"`
	NotifyGroupActivity    *bool   `json:"notify_group_activity"`
}

// IsEmpty reports whether the request changes nothing.
func (r UpdateSettingsRequest) IsEmpty() bool {
	return r.Language == nil && r.NotifyPaymentReminders == nil && r.NotifyDrawResults == nil && r.NotifyGroupActivity == nil
}

// PushTokenRequest is the body of PUT /me/push-token.
type PushTokenRequest struct {
	FCMToken string `json:"fcm_token" validate:"required,max=4096"`
}

// Session is the Session schema: one signed-in device.
type Session struct {
	ID             uuid.UUID            `json:"id"`
	DeviceName     *string              `json:"device_name"`
	DevicePlatform model.DevicePlatform `json:"device_platform"`
	LastActiveAt   time.Time            `json:"last_active_at"`
	CreatedAt      time.Time            `json:"created_at"`
	IsCurrent      bool                 `json:"is_current"`
}

// NewSessions maps sessions to Session, marking currentID.
func NewSessions(sessions []model.Session, currentID uuid.UUID) []Session {
	out := make([]Session, len(sessions))
	for i, s := range sessions {
		out[i] = Session{
			ID:             s.ID,
			DeviceName:     s.DeviceName,
			DevicePlatform: s.DevicePlatform,
			LastActiveAt:   s.LastActiveAt,
			CreatedAt:      s.CreatedAt,
			IsCurrent:      s.ID == currentID,
		}
	}
	return out
}
