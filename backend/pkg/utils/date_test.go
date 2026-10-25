package utils

import (
	"testing"
	"time"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

func TestToday(t *testing.T) {
	// Arrange
	jakarta, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		t.Fatalf("load location: %v", err)
	}
	tests := []struct {
		name string
		now  time.Time
		want time.Time
	}{
		{"same day in UTC and WIB", time.Date(2026, 10, 25, 3, 0, 0, 0, time.UTC), Date(2026, 10, 25)},
		{"already tomorrow in WIB", time.Date(2026, 10, 25, 17, 0, 0, 0, time.UTC), Date(2026, 10, 26)},
		{"last second of the WIB day", time.Date(2026, 10, 25, 16, 59, 59, 0, time.UTC), Date(2026, 10, 25)},
		{"new year in WIB", time.Date(2026, 12, 31, 18, 0, 0, 0, time.UTC), Date(2027, 1, 1)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := Today(tt.now, jakarta)

			// Assert
			if !got.Equal(tt.want) || got.Location() != time.UTC {
				t.Errorf("got %s, want %s", got, tt.want)
			}
		})
	}
}

func TestDueDate(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		start      time.Time
		periodType model.PeriodType
		periodNo   int
		want       time.Time
	}{
		{"weekly first period", Date(2026, 11, 2), model.PeriodTypeWeekly, 1, Date(2026, 11, 2)},
		{"weekly second period", Date(2026, 11, 2), model.PeriodTypeWeekly, 2, Date(2026, 11, 9)},
		{"weekly across year end", Date(2026, 12, 28), model.PeriodTypeWeekly, 2, Date(2027, 1, 4)},
		{"monthly first period", Date(2026, 11, 15), model.PeriodTypeMonthly, 1, Date(2026, 11, 15)},
		{"monthly same day", Date(2026, 11, 15), model.PeriodTypeMonthly, 3, Date(2027, 1, 15)},
		{"monthly 31st into February", Date(2027, 1, 31), model.PeriodTypeMonthly, 2, Date(2027, 2, 28)},
		{"monthly clamp does not carry over", Date(2027, 1, 31), model.PeriodTypeMonthly, 3, Date(2027, 3, 31)},
		{"monthly 31st into April", Date(2027, 1, 31), model.PeriodTypeMonthly, 4, Date(2027, 4, 30)},
		{"monthly leap February", Date(2028, 1, 30), model.PeriodTypeMonthly, 2, Date(2028, 2, 29)},
		{"monthly 50 periods", Date(2026, 11, 30), model.PeriodTypeMonthly, 50, Date(2030, 12, 30)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := DueDate(tt.start, tt.periodType, tt.periodNo)

			// Assert
			if !got.Equal(tt.want) {
				t.Errorf("got %s, want %s", got.Format(time.DateOnly), tt.want.Format(time.DateOnly))
			}
		})
	}
}
