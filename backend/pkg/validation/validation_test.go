package validation

import (
	"errors"
	"testing"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

type orderItem struct {
	SlotID   string `json:"slot_id" validate:"required"`
	Position int    `json:"position" validate:"min=1"`
}

type request struct {
	Name            string      `json:"name" validate:"required,min=3,max=60"`
	Amount          int64       `json:"amount" validate:"min=10000,max=100000000"`
	PeriodType      string      `json:"period_type" validate:"oneof=weekly monthly"`
	PIN             string      `json:"pin" validate:"len=6,numeric"`
	PINConfirmation string      `json:"pin_confirmation" validate:"eqfield=PIN"`
	Tags            []string    `json:"tags" validate:"max=2,unique"`
	Order           []orderItem `json:"order" validate:"dive"`
	Note            string      `validate:"max=5"`
}

func valid() request {
	return request{
		Name: "Arisan RT 05", Amount: 150_000, PeriodType: "monthly",
		PIN: "135792", PINConfirmation: "135792",
		Order: []orderItem{{SlotID: "a", Position: 1}},
	}
}

func TestValidateValid(t *testing.T) {
	// Arrange
	req := valid()

	// Act
	err := New().Validate(&req)

	// Assert
	if err != nil {
		t.Errorf("got %v, want nil", err)
	}
}

func TestValidateFieldErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name      string
		mutate    func(*request)
		wantField string
		wantCode  model.FieldCode
	}{
		{"required", func(r *request) { r.Name = "" }, "name", model.FieldRequired},
		{"string too short", func(r *request) { r.Name = "ab" }, "name", model.FieldMinLength},
		{"string too long", func(r *request) { r.Name = string(make([]byte, 61)) }, "name", model.FieldMaxLength},
		{"number too small", func(r *request) { r.Amount = 9_999 }, "amount", model.FieldMinimumValue},
		{"number too large", func(r *request) { r.Amount = 100_000_001 }, "amount", model.FieldMaximumValue},
		{"not a choice", func(r *request) { r.PeriodType = "daily" }, "period_type", model.FieldInvalidChoice},
		{"bad format", func(r *request) { r.PIN, r.PINConfirmation = "13579a", "13579a" }, "pin", model.FieldInvalidFormat},
		{"mismatch", func(r *request) { r.PINConfirmation = "135793" }, "pin_confirmation", model.FieldMismatch},
		{"too many items", func(r *request) { r.Tags = []string{"a", "b", "c"} }, "tags", model.FieldMaxLength},
		{"duplicate", func(r *request) { r.Tags = []string{"a", "a"} }, "tags", model.FieldDuplicate},
		{"nested path", func(r *request) { r.Order = append(r.Order, orderItem{SlotID: "b", Position: 0}) }, "order[1].position", model.FieldMinimumValue},
		{"no json tag", func(r *request) { r.Note = "too long" }, "Note", model.FieldMaxLength},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req := valid()
			tt.mutate(&req)

			// Act
			err := New().Validate(&req)

			// Assert
			var me *model.Error
			if !errors.As(err, &me) || !errors.Is(err, model.ErrValidation) {
				t.Fatalf("got %v, want validation_error", err)
			}
			if len(me.Fields) != 1 || me.Fields[0].Field != tt.wantField || me.Fields[0].Code != tt.wantCode {
				t.Errorf("got %+v, want one %s/%s", me.Fields, tt.wantField, tt.wantCode)
			}
			if me.Fields[0].Message == "" {
				t.Error("empty message")
			}
		})
	}
}

func TestValidateMismatchNamesOtherField(t *testing.T) {
	// Arrange
	req := valid()
	req.PINConfirmation = "135793"

	// Act
	err := New().Validate(&req)

	// Assert
	var me *model.Error
	if !errors.As(err, &me) || len(me.Fields) != 1 || me.Fields[0].Message != "Must match pin." {
		t.Errorf("got %v, want message naming pin", err)
	}
}

func TestValidateReportsEveryField(t *testing.T) {
	// Arrange
	req := valid()
	req.Name, req.Amount = "", 1

	// Act
	err := New().Validate(&req)

	// Assert
	var me *model.Error
	if !errors.As(err, &me) || len(me.Fields) != 2 {
		t.Fatalf("got %v, want two field errors", err)
	}
	if me.Fields[0].Field != "name" || me.Fields[1].Field != "amount" {
		t.Errorf("got %+v, want name then amount", me.Fields)
	}
}

func TestValidateNonStruct(t *testing.T) {
	// Act
	err := New().Validate("not a struct")

	// Assert
	if err == nil || errors.Is(err, model.ErrValidation) {
		t.Errorf("got %v, want a plain error", err)
	}
}
