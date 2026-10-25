// Package utils holds small pure helpers shared across layers: phone number
// normalization and business-date arithmetic.
package utils

import (
	"regexp"
	"strings"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// e164ID matches the Phone schema in api/api-spec.yaml and the users.phone
// CHECK: +62 followed by 8 to 13 digits.
var e164ID = regexp.MustCompile(`^\+62[0-9]{8,13}$`)

// NormalizePhone turns an Indonesian mobile number written as 08…, 628… or
// +628… into E.164 (+628…), ignoring spaces, dashes, dots and parentheses
// (FR-AUTH-01). field is the request field a validation error points at.
func NormalizePhone(field, raw string) (string, error) {
	s := strings.Map(func(r rune) rune {
		switch r {
		case ' ', '-', '.', '(', ')':
			return -1
		}
		return r
	}, raw)
	switch {
	case strings.HasPrefix(s, "+628"):
	case strings.HasPrefix(s, "628"):
		s = "+" + s
	case strings.HasPrefix(s, "08"):
		s = "+62" + s[1:]
	default:
		return "", invalidPhone(field)
	}
	if !e164ID.MatchString(s) {
		return "", invalidPhone(field)
	}
	return s, nil
}

func invalidPhone(field string) error {
	return model.NewValidationError(model.FieldError{
		Field: field, Code: model.FieldInvalidFormat, Message: "Phone must be an Indonesian mobile number (08…, 628… or +628…).",
	})
}
