package security

import (
	"regexp"
	"testing"

	"github.com/google/uuid"
)

var (
	otpSecret = []byte("giliran-test-otp-secret-0123456789abcdef")
	otpID     = uuid.MustParse("01890a5d-ac96-774b-bcce-b302099a8057")
)

// TestOTPGolden checks vectors computed independently with Python's hmac
// module. If they fail, fix the code, never the vectors: the API and the
// worker derive codes separately and must agree.
func TestOTPGolden(t *testing.T) {
	// Arrange
	tests := []struct {
		resendCount int
		code        string
		hash        string
	}{
		{0, "061594", "7e417ed9e4eb6c9042d03f6016414796b4301946047ee49a24793f86a9f2d579"},
		{1, "641388", "e0ff016f15e9427f372a403b9927b297afeeb002819b10e541a0f72f3250b829"},
		{5, "497563", "64c409d3397c88d0689e9c204ed8382ebccb93efeed3a545767094fc65bd2ab1"},
	}

	for _, tt := range tests {
		t.Run(tt.code, func(t *testing.T) {
			// Act
			code := OTPCode(otpSecret, otpID, tt.resendCount)
			hash := OTPCodeHash(otpSecret, otpID, code)

			// Assert
			if code != tt.code {
				t.Errorf("code %q, want %q", code, tt.code)
			}
			if hash != tt.hash {
				t.Errorf("hash %q, want %q", hash, tt.hash)
			}
		})
	}
}

func TestOTPCodeIsSixDigits(t *testing.T) {
	// Arrange
	digits := regexp.MustCompile(`^[0-9]{6}$`)
	ids := make([]uuid.UUID, 1000)
	for i := range ids {
		ids[i] = uuid.New()
	}

	for _, id := range ids {
		// Act
		got := OTPCode(otpSecret, id, 0)

		// Assert
		if !digits.MatchString(got) {
			t.Fatalf("OTPCode(%s) = %q, want 6 digits", id, got)
		}
	}
}

func TestOTPCodeDependsOnEveryInput(t *testing.T) {
	// Arrange
	base := OTPCode(otpSecret, otpID, 0)
	tests := []struct {
		name   string
		secret []byte
		id     uuid.UUID
		resend int
	}{
		{"resend count", otpSecret, otpID, 1},
		{"id", otpSecret, uuid.MustParse("01890a5d-ac96-774b-bcce-b302099a8058"), 0},
		{"secret", []byte("another-otp-secret-0123456789abcdef!"), otpID, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := OTPCode(tt.secret, tt.id, tt.resend)

			// Assert
			if got == base {
				t.Errorf("code %q unchanged", got)
			}
		})
	}
}

func TestOTPCodeHashFormat(t *testing.T) {
	// Arrange
	hexHash := regexp.MustCompile(`^[0-9a-f]{64}$`)

	// Act
	got := OTPCodeHash(otpSecret, otpID, "000000")

	// Assert
	if !hexHash.MatchString(got) {
		t.Errorf("hash %q does not match the code_hash CHECK", got)
	}
}

func TestOTPCodeMatches(t *testing.T) {
	// Arrange
	code := OTPCode(otpSecret, otpID, 0)
	stored := OTPCodeHash(otpSecret, otpID, code)
	tests := []struct {
		name   string
		id     uuid.UUID
		code   string
		stored string
		want   bool
	}{
		{"right code", otpID, code, stored, true},
		{"wrong code", otpID, "999999", stored, false},
		{"wrong id", uuid.MustParse("01890a5d-ac96-774b-bcce-b302099a8058"), code, stored, false},
		{"malformed hash", otpID, code, "not-hex", false},
		{"short hash", otpID, code, stored[:62], false},
		{"empty hash", otpID, code, "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := OTPCodeMatches(otpSecret, tt.id, tt.code, tt.stored)

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
