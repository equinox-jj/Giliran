// Package draw is the commit-reveal draw (DB_SCHEME §5, hmac-sha256-v1) and
// the fixed-order pick. It does no I/O, so published draws can be recomputed
// anywhere. Never change how Pick works: every published draw must stay
// verifiable. A new algorithm gets a new name instead.
package draw

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/google/uuid"
)

// SeedLength is the size in bytes of a draw seed.
const SeedLength = 32

var (
	// ErrNoEligible means every slot has already won.
	ErrNoEligible = errors.New("draw: no eligible slot")
	// ErrBadSeed means the seed is not 32 bytes of lowercase hex.
	ErrBadSeed = errors.New("draw: seed must be 64 lowercase hex characters")
)

// Commit returns a fresh seed and its commitment, both lowercase hex:
// hash = hex(SHA-256(seed bytes)). Publish only the hash until the draw.
func Commit() (seed, hash string, err error) {
	b := make([]byte, SeedLength)
	if _, err := rand.Read(b); err != nil {
		return "", "", fmt.Errorf("draw: read seed: %w", err)
	}
	return hex.EncodeToString(b), hashOf(b), nil
}

// Pick returns the winner of an hmac-sha256-v1 draw and its index in
// eligible, which must be the unwon slots sorted by slot_no:
//
//	mac   = HMAC-SHA256(key = seed bytes, message = periodID as lowercase UUID string)
//	index = uint64 big-endian(mac[0:8]) mod len(eligible)
func Pick(seed string, periodID uuid.UUID, eligible []uuid.UUID) (uuid.UUID, int, error) {
	if len(eligible) == 0 {
		return uuid.Nil, 0, ErrNoEligible
	}
	key, err := decodeSeed(seed)
	if err != nil {
		return uuid.Nil, 0, err
	}
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte(periodID.String()))
	sum := mac.Sum(nil)
	i := int(binary.BigEndian.Uint64(sum[:8]) % uint64(len(eligible))) //nolint:gosec // below len(eligible)
	return eligible[i], i, nil
}

// HashMatches reports whether seed is the preimage of the published hash.
func HashMatches(seed, seedHash string) bool {
	key, err := decodeSeed(seed)
	if err != nil {
		return false
	}
	return hmac.Equal([]byte(hashOf(key)), []byte(seedHash))
}

// Verification is the outcome of checking a published random draw.
type Verification struct {
	HashMatches   bool // SHA-256(seed) equals the published seed_hash
	WinnerMatches bool // recomputing Pick gives the stored winner
}

// Verify recomputes a published draw from its public data (DB_SCHEME §5
// step 6).
func Verify(seed, seedHash string, periodID uuid.UUID, eligible []uuid.UUID, winner uuid.UUID) Verification {
	got, _, err := Pick(seed, periodID, eligible)
	return Verification{HashMatches: HashMatches(seed, seedHash), WinnerMatches: err == nil && got == winner}
}

// FixedSlot is a slot of a fixed-order group.
type FixedSlot struct {
	ID       uuid.UUID
	Position int16 // fixed_order_position
	Won      bool
}

// NextFixed returns the unwon slot with the lowest position: the winner of
// a fixed-order period.
func NextFixed(slots []FixedSlot) (uuid.UUID, error) {
	var next *FixedSlot
	for i := range slots {
		if s := &slots[i]; !s.Won && (next == nil || s.Position < next.Position) {
			next = s
		}
	}
	if next == nil {
		return uuid.Nil, ErrNoEligible
	}
	return next.ID, nil
}

// MaskName shortens a name for public pages: the first word plus the last
// word's initial ("Rina Sari Dewi" → "Rina D."). A single word stays as it
// is.
func MaskName(name string) string {
	words := strings.Fields(name)
	switch len(words) {
	case 0:
		return ""
	case 1:
		return words[0]
	}
	r, _ := utf8.DecodeRuneInString(words[len(words)-1])
	return words[0] + " " + string(unicode.ToUpper(r)) + "."
}

func decodeSeed(seed string) ([]byte, error) {
	if len(seed) != 2*SeedLength || strings.ToLower(seed) != seed {
		return nil, ErrBadSeed
	}
	b, err := hex.DecodeString(seed)
	if err != nil {
		return nil, ErrBadSeed
	}
	return b, nil
}

func hashOf(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}
