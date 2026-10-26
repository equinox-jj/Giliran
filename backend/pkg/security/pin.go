// Package security holds the app's cryptography: PIN hashing, access tokens,
// random tokens and codes, and SHA-256 helpers.
package security

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// PINLength is the number of digits in an app PIN (FR-AUTH-02).
const PINLength = 6

// errMalformedHash is returned by Verify for a stored hash it cannot parse.
var errMalformedHash = errors.New("security: malformed argon2id hash")

// maxKeyLength caps the key length Verify accepts from a stored hash, far
// above any configured Argon2KeyLength.
const maxKeyLength = 1024

// PINHasher hashes PINs with argon2id. Hashes are stored in the PHC string
// format, so they carry their own parameters and keep verifying after the
// configured parameters change.
type PINHasher struct {
	memoryKiB   uint32
	iterations  uint32
	parallelism uint8
	saltLength  uint32
	keyLength   uint32
}

// NewPINHasher builds a PINHasher from the PIN_ARGON2_* settings.
func NewPINHasher(cfg *config.Config) *PINHasher {
	p := cfg.PIN
	return &PINHasher{
		memoryKiB:   p.Argon2MemoryKiB,
		iterations:  p.Argon2Iterations,
		parallelism: p.Argon2Parallelism,
		saltLength:  p.Argon2SaltLength,
		keyLength:   p.Argon2KeyLength,
	}
}

// Hash returns pin as "$argon2id$v=19$m=…,t=…,p=…$<salt>$<key>", with salt and
// key in unpadded standard base64.
func (h *PINHasher) Hash(pin string) (string, error) {
	salt := make([]byte, h.saltLength)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("security: read salt: %w", err)
	}
	key := argon2.IDKey([]byte(pin), salt, h.iterations, h.memoryKiB, h.parallelism, h.keyLength)
	b64 := base64.RawStdEncoding
	return fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version, h.memoryKiB, h.iterations, h.parallelism,
		b64.EncodeToString(salt), b64.EncodeToString(key)), nil
}

// Verify reports whether pin matches encoded, using the parameters stored in
// encoded. It returns an error only when encoded is malformed.
func (h *PINHasher) Verify(pin, encoded string) (bool, error) {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[0] != "" || parts[1] != "argon2id" {
		return false, errMalformedHash
	}
	var version int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil || version != argon2.Version {
		return false, errMalformedHash
	}
	var memory, iterations uint32
	var parallelism uint8
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &iterations, &parallelism); err != nil ||
		iterations == 0 || parallelism == 0 {
		return false, errMalformedHash
	}
	b64 := base64.RawStdEncoding
	salt, err := b64.DecodeString(parts[4])
	if err != nil || len(salt) == 0 {
		return false, errMalformedHash
	}
	want, err := b64.DecodeString(parts[5])
	if err != nil || len(want) == 0 || len(want) > maxKeyLength {
		return false, errMalformedHash
	}
	got := argon2.IDKey([]byte(pin), salt, iterations, memory, parallelism, uint32(len(want))) //nolint:gosec // bounded by maxKeyLength
	return subtle.ConstantTimeCompare(got, want) == 1, nil
}

// ValidatePIN checks the PIN rules from FR-AUTH-02: exactly six digits, and
// neither one repeated digit (111111) nor a run up or down (123456, 654321).
// field is the request field the error points at, e.g. "pin" or "new_pin".
func ValidatePIN(field, pin string) error {
	if len(pin) != PINLength || strings.Trim(pin, "0123456789") != "" {
		return model.NewValidationError(model.FieldError{
			Field: field, Code: model.FieldInvalidFormat, Message: "PIN must be exactly 6 digits.",
		})
	}
	if isRepeated(pin) || isSequential(pin, 1) || isSequential(pin, -1) {
		return model.NewValidationError(model.FieldError{
			Field: field, Code: model.FieldPINTooWeak, Message: "PIN must not be a sequence or a repeated digit.",
		})
	}
	return nil
}

func isRepeated(pin string) bool {
	return strings.Count(pin, pin[:1]) == len(pin)
}

// isSequential reports whether each digit is the previous one plus step.
func isSequential(pin string, step int) bool {
	for i := 1; i < len(pin); i++ {
		if int(pin[i])-int(pin[i-1]) != step {
			return false
		}
	}
	return true
}
