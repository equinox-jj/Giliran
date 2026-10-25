package utils

import (
	"errors"
	"testing"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

func TestNormalizePhone(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		raw  string
		want string
	}{
		{"local 08", "081234567890", "+6281234567890"},
		{"country code 628", "6281234567890", "+6281234567890"},
		{"E.164", "+6281234567890", "+6281234567890"},
		{"spaces and dashes", "0812-3456 7890", "+6281234567890"},
		{"dots and parentheses", "(0812) 3456.7890", "+6281234567890"},
		{"shortest", "081234567", "+6281234567"},
		{"longest", "+628123456789012", "+628123456789012"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := NormalizePhone("phone", tt.raw)

			// Assert
			if err != nil {
				t.Fatalf("got error %v", err)
			}
			if got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

func TestNormalizePhoneRejects(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		raw  string
	}{
		{"empty", ""},
		{"landline 021", "0215551234"},
		{"landline 6221", "62215551234"},
		{"other country", "+6591234567"},
		{"no prefix", "81234567890"},
		{"too short", "08123456"},
		{"too long", "+6281234567890123"},
		{"letters", "0812345678ab"},
		{"double plus", "++6281234567890"},
		{"plus inside", "08123+4567890"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := NormalizePhone("guest_phone", tt.raw)

			// Assert
			var me *model.Error
			if !errors.As(err, &me) || !errors.Is(err, model.ErrValidation) {
				t.Fatalf("got %v, want validation_error", err)
			}
			if len(me.Fields) != 1 || me.Fields[0].Field != "guest_phone" || me.Fields[0].Code != model.FieldInvalidFormat {
				t.Errorf("got fields %+v, want guest_phone/invalid_format", me.Fields)
			}
		})
	}
}
