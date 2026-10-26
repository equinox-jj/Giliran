package draw

import (
	"encoding/json"
	"errors"
	"os"
	"testing"

	"github.com/google/uuid"
)

type goldenVector struct {
	Seed            string      `json:"seed"`
	SeedHash        string      `json:"seed_hash"`
	PeriodID        uuid.UUID   `json:"period_id"`
	EligibleSlotIDs []uuid.UUID `json:"eligible_slot_ids"`
	Index           int         `json:"index"`
	WinnerSlotID    uuid.UUID   `json:"winner_slot_id"`
}

// loadGolden reads vectors computed by an independent implementation. They
// pin hmac-sha256-v1: if a test here fails, published draws would no longer
// verify, so fix the code, never the vectors.
func loadGolden(t *testing.T) []goldenVector {
	t.Helper()
	data, err := os.ReadFile("testdata/golden.json")
	if err != nil {
		t.Fatal(err)
	}
	var f struct {
		Vectors []goldenVector `json:"vectors"`
	}
	if err := json.Unmarshal(data, &f); err != nil {
		t.Fatal(err)
	}
	if len(f.Vectors) == 0 {
		t.Fatal("no golden vectors")
	}
	return f.Vectors
}

func TestPickGoldenVectors(t *testing.T) {
	// Arrange
	vectors := loadGolden(t)

	for _, v := range vectors {
		t.Run(v.PeriodID.String(), func(t *testing.T) {
			// Act
			winner, index, err := Pick(v.Seed, v.PeriodID, v.EligibleSlotIDs)

			// Assert
			if err != nil {
				t.Fatal(err)
			}
			if index != v.Index || winner != v.WinnerSlotID {
				t.Errorf("Pick = (%s, %d), want (%s, %d)", winner, index, v.WinnerSlotID, v.Index)
			}
		})
	}
}

func TestVerifyGoldenVectors(t *testing.T) {
	// Arrange
	vectors := loadGolden(t)

	for _, v := range vectors {
		t.Run(v.PeriodID.String(), func(t *testing.T) {
			// Act
			got := Verify(v.Seed, v.SeedHash, v.PeriodID, v.EligibleSlotIDs, v.WinnerSlotID)

			// Assert
			if !got.HashMatches || !got.WinnerMatches {
				t.Errorf("Verify = %+v, want both true", got)
			}
		})
	}
}

func TestVerifyDetectsTampering(t *testing.T) {
	// Arrange
	v := loadGolden(t)[0]
	other := v.EligibleSlotIDs[(v.Index+1)%len(v.EligibleSlotIDs)]
	tests := []struct {
		name       string
		seed       string
		seedHash   string
		periodID   uuid.UUID
		eligible   []uuid.UUID
		winner     uuid.UUID
		wantHash   bool
		wantWinner bool
	}{
		{"other winner", v.Seed, v.SeedHash, v.PeriodID, v.EligibleSlotIDs, other, true, false},
		{"other seed", "11" + v.Seed[2:], v.SeedHash, v.PeriodID, v.EligibleSlotIDs, v.WinnerSlotID, false, false},
		{"other hash", v.Seed, "00" + v.SeedHash[2:], v.PeriodID, v.EligibleSlotIDs, v.WinnerSlotID, false, true},
		{"other period", v.Seed, v.SeedHash, uuid.MustParse("0193a1b2-c3d4-7e5f-8a6b-ffffffffffff"), v.EligibleSlotIDs, v.WinnerSlotID, true, false},
		{"eligible list dropped a slot", v.Seed, v.SeedHash, v.PeriodID, v.EligibleSlotIDs[1:], v.WinnerSlotID, true, false},
		{"uppercase seed", "AB" + v.Seed[2:], v.SeedHash, v.PeriodID, v.EligibleSlotIDs, v.WinnerSlotID, false, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := Verify(tt.seed, tt.seedHash, tt.periodID, tt.eligible, tt.winner)

			// Assert
			if got.HashMatches != tt.wantHash || got.WinnerMatches != tt.wantWinner {
				t.Errorf("Verify = %+v, want hash %v winner %v", got, tt.wantHash, tt.wantWinner)
			}
		})
	}
}

func TestPickErrors(t *testing.T) {
	// Arrange
	v := loadGolden(t)[0]
	tests := []struct {
		name     string
		seed     string
		eligible []uuid.UUID
		want     error
	}{
		{"no eligible slot", v.Seed, nil, ErrNoEligible},
		{"short seed", v.Seed[:62], v.EligibleSlotIDs, ErrBadSeed},
		{"not hex", "zz" + v.Seed[2:], v.EligibleSlotIDs, ErrBadSeed},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, _, err := Pick(tt.seed, v.PeriodID, tt.eligible)

			// Assert
			if !errors.Is(err, tt.want) {
				t.Errorf("err = %v, want %v", err, tt.want)
			}
		})
	}
}

func TestCommit(t *testing.T) {
	// Act
	seed, hash, err := Commit()

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if len(seed) != 64 || len(hash) != 64 {
		t.Fatalf("seed %q hash %q, want 64 hex characters each", seed, hash)
	}
	if !HashMatches(seed, hash) {
		t.Error("hash does not commit to seed")
	}
}

func TestNextFixed(t *testing.T) {
	// Arrange
	a, b, c := uuid.New(), uuid.New(), uuid.New()
	tests := []struct {
		name    string
		slots   []FixedSlot
		want    uuid.UUID
		wantErr error
	}{
		{"lowest position first", []FixedSlot{{ID: a, Position: 3}, {ID: b, Position: 1}, {ID: c, Position: 2}}, b, nil},
		{"skips slots that won", []FixedSlot{{ID: a, Position: 3}, {ID: b, Position: 1, Won: true}, {ID: c, Position: 2}}, c, nil},
		{"all won", []FixedSlot{{ID: a, Position: 1, Won: true}}, uuid.Nil, ErrNoEligible},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := NextFixed(tt.slots)

			// Assert
			if !errors.Is(err, tt.wantErr) || got != tt.want {
				t.Errorf("NextFixed = (%s, %v), want (%s, %v)", got, err, tt.want, tt.wantErr)
			}
		})
	}
}

func TestMaskName(t *testing.T) {
	// Arrange
	tests := []struct {
		in, want string
	}{
		{"Rina Sari Dewi", "Rina D."},
		{"Dimas Pratama", "Dimas P."},
		{"Budi", "Budi"},
		{"  ayu   wulandari ", "ayu W."},
		{"Rina élise", "Rina É."},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.in, func(t *testing.T) {
			// Act
			got := MaskName(tt.in)

			// Assert
			if got != tt.want {
				t.Errorf("MaskName(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}
