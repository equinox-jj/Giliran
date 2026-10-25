// Package validation checks request DTOs with go-playground/validator struct
// tags and reports failures as a model validation_error, so they render as
// 422 problem+json with errors[] through pkg/response.
package validation

import (
	"errors"
	"fmt"
	"reflect"
	"strings"

	"github.com/go-playground/validator/v10"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// Validator implements fiber.StructValidator: c.Bind().Body(&req) runs it
// after decoding, and its *model.Error reaches the central ErrorHandler.
type Validator struct {
	v *validator.Validate
}

// New returns a Validator that names fields by their JSON tag.
func New() *Validator {
	v := validator.New(validator.WithRequiredStructEnabled())
	v.RegisterTagNameFunc(tagName)
	return &Validator{v: v}
}

// Validate checks out's struct tags. Failures return a validation_error with
// one FieldError per failed field; a non-struct argument is a programming
// error and returns a plain error.
func (val *Validator) Validate(out any) error {
	err := val.v.Struct(out)
	if err == nil {
		return nil
	}
	var verrs validator.ValidationErrors
	if !errors.As(err, &verrs) {
		return fmt.Errorf("validation: %w", err)
	}
	root := reflect.TypeOf(out)
	fields := make([]model.FieldError, 0, len(verrs))
	for _, fe := range verrs {
		code, msg := describe(fe, root)
		fields = append(fields, model.FieldError{Field: fieldPath(fe), Code: code, Message: msg})
	}
	return model.NewValidationError(fields...)
}

// fieldPath is the JSON path of the field, e.g. "order[2].position": the
// namespace without the root struct's name.
func fieldPath(fe validator.FieldError) string {
	_, path, found := strings.Cut(fe.Namespace(), ".")
	if !found {
		return fe.Field()
	}
	return path
}

// describe maps a failed tag to the spec's FieldError code and a message.
func describe(fe validator.FieldError, root reflect.Type) (model.FieldCode, string) {
	sized := isSized(fe.Kind())
	switch fe.Tag() {
	case "required", "required_if", "required_unless", "required_with", "required_without":
		return model.FieldRequired, "This field is required."
	case "min", "gte":
		if sized {
			return model.FieldMinLength, fmt.Sprintf("Must have at least %s %s.", fe.Param(), unit(fe.Kind()))
		}
		return model.FieldMinimumValue, fmt.Sprintf("Must be at least %s.", fe.Param())
	case "max", "lte":
		if sized {
			return model.FieldMaxLength, fmt.Sprintf("Must have at most %s %s.", fe.Param(), unit(fe.Kind()))
		}
		return model.FieldMaximumValue, fmt.Sprintf("Must be at most %s.", fe.Param())
	case "oneof":
		return model.FieldInvalidChoice, fmt.Sprintf("Must be one of: %s.", strings.Join(strings.Fields(fe.Param()), ", "))
	case "unique":
		return model.FieldDuplicate, "Must not contain duplicates."
	case "eqfield":
		return model.FieldMismatch, fmt.Sprintf("Must match %s.", otherField(fe, root))
	default:
		return model.FieldInvalidFormat, "Has an invalid format."
	}
}

// otherField is the JSON name of the field an eqfield tag compares against.
// The validator only reports its Go name, so look it up on the parent struct,
// found by walking the struct namespace from root.
func otherField(fe validator.FieldError, root reflect.Type) string {
	t := root
	segs := strings.Split(fe.StructNamespace(), ".")
	for _, seg := range segs[1 : len(segs)-1] {
		name, _, _ := strings.Cut(seg, "[")
		f, ok := structType(t).FieldByName(name)
		if !ok {
			return fe.Param()
		}
		t = f.Type
	}
	f, ok := structType(t).FieldByName(fe.Param())
	if !ok {
		return fe.Param()
	}
	return tagName(f)
}

// structType unwraps pointers, slices, arrays and maps down to the element
// type a namespace segment refers to.
func structType(t reflect.Type) reflect.Type {
	for {
		switch t.Kind() {
		case reflect.Pointer, reflect.Slice, reflect.Array, reflect.Map:
			t = t.Elem()
		default:
			return t
		}
	}
}

// tagName is the field's JSON name, or its Go name when it has no json tag.
func tagName(f reflect.StructField) string {
	name, _, _ := strings.Cut(f.Tag.Get("json"), ",")
	if name == "-" {
		return ""
	}
	if name == "" {
		return f.Name
	}
	return name
}

func isSized(k reflect.Kind) bool {
	switch k {
	case reflect.String, reflect.Slice, reflect.Array, reflect.Map:
		return true
	}
	return false
}

func unit(k reflect.Kind) string {
	if k == reflect.String {
		return "characters"
	}
	return "items"
}
