package utils

import (
	"errors"
	"strings"
	"testing"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

func TestNormalizeEmail(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		raw  string
		want string
	}{
		{"already normal", "rina@gmail.com", "rina@gmail.com"},
		{"uppercase", "Rina.S@GMail.COM", "rina.s@gmail.com"},
		{"surrounding spaces", "  rina@gmail.com\n", "rina@gmail.com"},
		{"plus addressing", "rina+giliran@gmail.com", "rina+giliran@gmail.com"},
		{"subdomain", "budi@mail.example.co.id", "budi@mail.example.co.id"},
		{"longest", strings.Repeat("a", 244) + "@gmail.com", strings.Repeat("a", 244) + "@gmail.com"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := NormalizeEmail("email", tt.raw)

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

func TestNormalizeEmailRejects(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		raw  string
	}{
		{"empty", ""},
		{"blank", "   "},
		{"no at", "rina.gmail.com"},
		{"two ats", "rina@x@gmail.com"},
		{"no local part", "@gmail.com"},
		{"no dot in domain", "rina@localhost"},
		{"inner space", "ri na@gmail.com"},
		{"too long", strings.Repeat("a", 245) + "@gmail.com"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := NormalizeEmail("new_email", tt.raw)

			// Assert
			var me *model.Error
			if !errors.As(err, &me) || !errors.Is(err, model.ErrValidation) {
				t.Fatalf("got %v, want validation_error", err)
			}
			if len(me.Fields) != 1 || me.Fields[0].Field != "new_email" || me.Fields[0].Code != model.FieldInvalidFormat {
				t.Errorf("got fields %+v, want new_email/invalid_format", me.Fields)
			}
		})
	}
}

func TestMaskEmail(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		email string
		want  string
	}{
		{"long local part", "rina.susanti@gmail.com", "ri•••••@gmail.com"},
		{"three characters", "rin@gmail.com", "ri•••••@gmail.com"},
		{"two characters", "ri@gmail.com", "r•••••@gmail.com"},
		{"one character", "r@gmail.com", "r•••••@gmail.com"},
		{"empty local part", "@gmail.com", "•••••@gmail.com"},
		{"no at", "rina", "•••••"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := MaskEmail(tt.email)

			// Assert
			if got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}
