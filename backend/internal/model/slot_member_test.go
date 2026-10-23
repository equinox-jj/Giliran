package model

import "testing"

func TestSlotMemberShareOf(t *testing.T) {
	// Arrange
	tests := []struct {
		name        string
		basisPoints int32
		amount      int64
		want        int64
	}{
		{"full share", FullShareBasisPoints, 150_000, 150_000},
		{"half share", 5_000, 150_000, 75_000},
		{"rounds down", 3_333, 100_000, 33_330},
		{"max amount", FullShareBasisPoints, MaxGroupAmount, MaxGroupAmount},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sm := SlotMember{SharePctBasisPoints: tt.basisPoints}

			// Act
			got := sm.ShareOf(tt.amount)

			// Assert
			if got != tt.want {
				t.Errorf("got %d, want %d", got, tt.want)
			}
		})
	}
}
