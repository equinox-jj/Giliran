package security

import (
	"encoding/base64"
	"regexp"
	"testing"
)

func TestRandomCode(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		n    int
		re   *regexp.Regexp
	}{
		{"invite code", 8, regexp.MustCompile(`^[A-Z0-9]{8}$`)},
		{"verification code", 10, regexp.MustCompile(`^[A-Z0-9]{10}$`)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := RandomCode(tt.n)

			// Assert
			if err != nil {
				t.Fatalf("RandomCode: %v", err)
			}
			if !tt.re.MatchString(got) {
				t.Errorf("got %q, want %s", got, tt.re)
			}
		})
	}
}

func TestRandomCodeUsesWholeAlphabet(t *testing.T) {
	// Arrange
	seen := map[rune]bool{}

	// Act
	for range 200 {
		code, err := RandomCode(10)
		if err != nil {
			t.Fatalf("RandomCode: %v", err)
		}
		for _, r := range code {
			seen[r] = true
		}
	}

	// Assert
	if len(seen) != len(codeAlphabet) {
		t.Errorf("saw %d distinct characters in 2000 draws, want %d", len(seen), len(codeAlphabet))
	}
}

func TestRandomToken(t *testing.T) {
	// Arrange
	seen := map[string]bool{}

	// Act
	for range 1000 {
		token, err := RandomToken(32)
		if err != nil {
			t.Fatalf("RandomToken: %v", err)
		}
		seen[token] = true
	}

	// Assert
	if len(seen) != 1000 {
		t.Errorf("got %d unique tokens, want 1000", len(seen))
	}
	for token := range seen {
		b, err := base64.RawURLEncoding.DecodeString(token)
		if err != nil || len(b) != 32 {
			t.Fatalf("token %q decodes to %d bytes (%v), want 32", token, len(b), err)
		}
		break
	}
}

func TestSeed(t *testing.T) {
	// Act
	seed, err := Seed()

	// Assert
	if err != nil {
		t.Fatalf("Seed: %v", err)
	}
	if len(seed) != SeedLength {
		t.Errorf("got %d bytes, want %d", len(seed), SeedLength)
	}
}
