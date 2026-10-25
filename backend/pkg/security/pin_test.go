package security

import (
	"errors"
	"strings"
	"testing"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// testHasher uses small argon2 parameters so the tests stay fast.
func testHasher(memoryKiB, iterations uint32) *PINHasher {
	return NewPINHasher(&config.Config{PIN: config.PIN{
		Argon2MemoryKiB:   memoryKiB,
		Argon2Iterations:  iterations,
		Argon2Parallelism: 1,
		Argon2SaltLength:  16,
		Argon2KeyLength:   32,
	}})
}

func TestPINHasherVerify(t *testing.T) {
	// Arrange
	h := testHasher(64, 1)
	encoded, err := h.Hash("135792")
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}
	tests := []struct {
		name string
		pin  string
		want bool
	}{
		{"correct PIN", "135792", true},
		{"wrong PIN", "135793", false},
		{"empty PIN", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := h.Verify(tt.pin, encoded)

			// Assert
			if err != nil {
				t.Fatalf("Verify: %v", err)
			}
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestPINHasherHashFormat(t *testing.T) {
	// Arrange
	h := testHasher(64, 1)

	// Act
	encoded, err := h.Hash("135792")

	// Assert
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}
	if !strings.HasPrefix(encoded, "$argon2id$v=19$m=64,t=1,p=1$") {
		t.Errorf("got %q, want PHC argon2id prefix", encoded)
	}
}

func TestPINHasherHashIsSalted(t *testing.T) {
	// Arrange
	h := testHasher(64, 1)
	first, err := h.Hash("135792")
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}

	// Act
	second, err := h.Hash("135792")

	// Assert
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}
	if first == second {
		t.Error("two hashes of the same PIN are equal")
	}
}

func TestPINHasherVerifiesOldParameters(t *testing.T) {
	// Arrange
	encoded, err := testHasher(64, 1).Hash("135792")
	if err != nil {
		t.Fatalf("Hash: %v", err)
	}
	current := testHasher(128, 2)

	// Act
	got, err := current.Verify("135792", encoded)

	// Assert
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if !got {
		t.Error("hash made with older parameters no longer verifies")
	}
}

func TestPINHasherVerifyMalformed(t *testing.T) {
	// Arrange
	h := testHasher(64, 1)
	tests := []struct {
		name    string
		encoded string
	}{
		{"empty", ""},
		{"bcrypt", "$2a$10$abcdefghijklmnopqrstuuabcdefghijklmnopqrstuvwxyz01234"},
		{"argon2i", "$argon2i$v=19$m=64,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$a2V5"},
		{"wrong version", "$argon2id$v=16$m=64,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$a2V5"},
		{"bad params", "$argon2id$v=19$m=x,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$a2V5"},
		{"zero iterations", "$argon2id$v=19$m=64,t=0,p=1$c2FsdHNhbHRzYWx0c2FsdA$a2V5"},
		{"bad salt", "$argon2id$v=19$m=64,t=1,p=1$!!!$a2V5"},
		{"empty key", "$argon2id$v=19$m=64,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			ok, err := h.Verify("135792", tt.encoded)

			// Assert
			if !errors.Is(err, errMalformedHash) {
				t.Errorf("got err %v, want errMalformedHash", err)
			}
			if ok {
				t.Error("malformed hash verified")
			}
		})
	}
}

func TestValidatePIN(t *testing.T) {
	// Arrange
	tests := []struct {
		pin  string
		want model.FieldCode // empty means valid
	}{
		{"135792", ""},
		{"204816", ""},
		{"123457", ""},
		{"123456", model.FieldPINTooWeak},
		{"654321", model.FieldPINTooWeak},
		{"456789", model.FieldPINTooWeak},
		{"111111", model.FieldPINTooWeak},
		{"000000", model.FieldPINTooWeak},
		{"12345", model.FieldInvalidFormat},
		{"1234567", model.FieldInvalidFormat},
		{"12a456", model.FieldInvalidFormat},
		{"١٢٣٤٥٦", model.FieldInvalidFormat},
		{"", model.FieldInvalidFormat},
	}

	for _, tt := range tests {
		t.Run(tt.pin, func(t *testing.T) {
			// Act
			err := ValidatePIN("new_pin", tt.pin)

			// Assert
			if tt.want == "" {
				if err != nil {
					t.Errorf("got %v, want nil", err)
				}
				return
			}
			var me *model.Error
			if !errors.As(err, &me) || !errors.Is(err, model.ErrValidation) {
				t.Fatalf("got %v, want validation_error", err)
			}
			if len(me.Fields) != 1 || me.Fields[0].Field != "new_pin" || me.Fields[0].Code != tt.want {
				t.Errorf("got fields %+v, want new_pin/%s", me.Fields, tt.want)
			}
		})
	}
}
