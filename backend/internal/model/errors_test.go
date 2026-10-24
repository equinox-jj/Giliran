package model

import (
	"errors"
	"fmt"
	"testing"
)

func TestErrorIs(t *testing.T) {
	// Arrange
	tests := []struct {
		name   string
		err    error
		target error
		want   bool
	}{
		{"same sentinel", ErrGroupNotFound, ErrGroupNotFound, true},
		{"wrapped", fmt.Errorf("load group: %w", ErrGroupNotFound), ErrGroupNotFound, true},
		{"with detail", ErrPeriodNotOpen.WithDetail("period %d is closed", 3), ErrPeriodNotOpen, true},
		{"validation copy", NewValidationError(FieldError{Field: "amount"}), ErrValidation, true},
		{"different code", ErrGroupNotFound, ErrMemberNotFound, false},
		{"plain error", errors.New("group_not_found"), ErrGroupNotFound, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := errors.Is(tt.err, tt.target)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestErrorWithDetailLeavesSentinelUnchanged(t *testing.T) {
	// Arrange
	original := ErrDrawTooEarly.Message

	// Act
	got := ErrDrawTooEarly.WithDetail("draw opens on %s", "2026-11-01")

	// Assert
	if got.Message != "draw opens on 2026-11-01" {
		t.Errorf("got message %q", got.Message)
	}
	if got.Code != ErrDrawTooEarly.Code || got.Kind != ErrDrawTooEarly.Kind {
		t.Errorf("got %s/%d, want %s/%d", got.Code, got.Kind, ErrDrawTooEarly.Code, ErrDrawTooEarly.Kind)
	}
	if ErrDrawTooEarly.Message != original {
		t.Errorf("sentinel mutated to %q", ErrDrawTooEarly.Message)
	}
}

func TestErrorWithExtensionsLeavesSentinelUnchanged(t *testing.T) {
	// Arrange
	ext := map[string]any{"paid_count": 8, "total_count": 10}

	// Act
	got := ErrPaymentsIncomplete.WithExtensions(ext)

	// Assert
	if got.Extensions["paid_count"] != 8 || got.Extensions["total_count"] != 10 {
		t.Errorf("got extensions %+v", got.Extensions)
	}
	if !errors.Is(got, ErrPaymentsIncomplete) {
		t.Errorf("copy no longer matches its sentinel")
	}
	if ErrPaymentsIncomplete.Extensions != nil {
		t.Errorf("sentinel mutated: %+v", ErrPaymentsIncomplete.Extensions)
	}
}

func TestNewValidationError(t *testing.T) {
	// Arrange
	fields := []FieldError{
		{Field: "amount", Code: FieldMinimumValue, Message: "Must be at least 1."},
		{Field: "order[2].position", Code: FieldDuplicate, Message: "Position already used."},
	}

	// Act
	got := NewValidationError(fields...)

	// Assert
	if got.Kind != KindInvalid || got.Code != "validation_error" {
		t.Errorf("got %d/%s, want KindInvalid/validation_error", got.Kind, got.Code)
	}
	if len(got.Fields) != 2 || got.Fields[1].Field != "order[2].position" {
		t.Errorf("got fields %+v", got.Fields)
	}
	if ErrValidation.Fields != nil {
		t.Errorf("sentinel mutated: %+v", ErrValidation.Fields)
	}
}

func TestErrorError(t *testing.T) {
	// Act
	got := ErrGroupFull.Error()

	// Assert
	if got != "group_full: The group has no free slots." {
		t.Errorf("got %q", got)
	}
}
