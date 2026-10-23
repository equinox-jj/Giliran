package model

import "testing"

func TestPeriodStatusCanTransitionTo(t *testing.T) {
	// Arrange
	allowed := map[[2]PeriodStatus]bool{
		{PeriodStatusUpcoming, PeriodStatusOpen}: true,
		{PeriodStatusOpen, PeriodStatusDrawn}:    true,
		{PeriodStatusDrawn, PeriodStatusClosed}:  true,
	}
	statuses := []PeriodStatus{PeriodStatusUpcoming, PeriodStatusOpen, PeriodStatusDrawn, PeriodStatusClosed}

	for _, from := range statuses {
		for _, to := range statuses {
			want := allowed[[2]PeriodStatus{from, to}]

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

func TestPeriodStatusIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value PeriodStatus
		want  bool
	}{
		{"upcoming", PeriodStatusUpcoming, true},
		{"open", PeriodStatusOpen, true},
		{"drawn", PeriodStatusDrawn, true},
		{"closed", PeriodStatusClosed, true},
		{"skipped", PeriodStatus("skipped"), false},
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

func TestPeriodIsDrawn(t *testing.T) {
	// Arrange
	tests := []struct {
		status PeriodStatus
		want   bool
	}{
		{PeriodStatusUpcoming, false},
		{PeriodStatusOpen, false},
		{PeriodStatusDrawn, true},
		{PeriodStatusClosed, true},
	}

	for _, tt := range tests {
		t.Run(string(tt.status), func(t *testing.T) {
			p := Period{Status: tt.status}

			// Act
			got := p.IsDrawn()

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
