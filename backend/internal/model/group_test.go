package model

import "testing"

func TestGroupStatusCanTransitionTo(t *testing.T) {
	// Arrange
	allowed := map[[2]GroupStatus]bool{
		{GroupStatusDraft, GroupStatusActive}:     true,
		{GroupStatusDraft, GroupStatusClosed}:     true,
		{GroupStatusActive, GroupStatusCompleted}: true,
		{GroupStatusActive, GroupStatusClosed}:    true,
	}
	statuses := []GroupStatus{GroupStatusDraft, GroupStatusActive, GroupStatusCompleted, GroupStatusClosed}

	for _, from := range statuses {
		for _, to := range statuses {
			want := allowed[[2]GroupStatus{from, to}]

			t.Run(string(from)+"->"+string(to), func(t *testing.T) {
				// Act
				got := from.CanTransitionTo(to)

				// Assert
				if got != want {
					t.Errorf("got %v, want %v", got, want)
				}
			})
		}
	}
}

func TestGroupEnumsIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value interface{ IsValid() bool }
		want  bool
	}{
		{"weekly", PeriodTypeWeekly, true},
		{"monthly", PeriodTypeMonthly, true},
		{"daily", PeriodType("daily"), false},
		{"random", DrawMethodRandom, true},
		{"fixed_order", DrawMethodFixedOrder, true},
		{"bid", DrawMethod("bid"), false},
		{"completed", GroupStatusCompleted, true},
		{"archived", GroupStatus("archived"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := tt.value.IsValid()

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGroupTotalPot(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		group Group
		want  int64
	}{
		{"typical", Group{Amount: 150_000, TotalSlots: 10}, 1_500_000},
		{"max", Group{Amount: MaxGroupAmount, TotalSlots: MaxGroupSlots}, 5_000_000_000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := tt.group.TotalPot()

			// Assert
			if got != tt.want {
				t.Errorf("got %d, want %d", got, tt.want)
			}
		})
	}
}
