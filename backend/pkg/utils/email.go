package utils

import (
	"regexp"
	"strings"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// emailFormat matches the Email schema in api/api-spec.yaml and the
// users.email and email_otp_requests.email CHECKs.
var emailFormat = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// maxEmailLength is the RFC 5321 path limit the CHECKs also enforce.
const maxEmailLength = 254

// emailMask hides the rest of the local part. It has a fixed length so the
// mask doesn't reveal how long the address is.
const emailMask = "•••••"

// NormalizeEmail trims and lowercases an email address, which is how emails
// are stored (FR-AUTH-01). field is the request field a validation error
// points at.
func NormalizeEmail(field, raw string) (string, error) {
	s := strings.ToLower(strings.TrimSpace(raw))
	if len(s) > maxEmailLength || !emailFormat.MatchString(s) {
		return "", model.NewValidationError(model.FieldError{
			Field: field, Code: model.FieldInvalidFormat, Message: "Email must be a valid address.",
		})
	}
	return s, nil
}

// MaskEmail shows the first two characters of the local part (one when it is
// two or shorter) and the domain: "rina@gmail.com" → "ri•••••@gmail.com".
func MaskEmail(email string) string {
	at := strings.LastIndexByte(email, '@')
	if at < 0 {
		return emailMask
	}
	local := []rune(email[:at])
	keep := 2
	if len(local) <= 2 {
		keep = 1
	}
	keep = min(keep, len(local))
	return string(local[:keep]) + emailMask + email[at:]
}
