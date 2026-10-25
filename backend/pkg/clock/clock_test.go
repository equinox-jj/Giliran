package clock

import (
	"testing"
	"time"
)

func TestSystemNowIsUTC(t *testing.T) {
	// Act
	got := System{}.Now()

	// Assert
	if got.Location() != time.UTC {
		t.Errorf("got location %s, want UTC", got.Location())
	}
}

func TestFakeNow(t *testing.T) {
	// Arrange
	jakarta := time.FixedZone("WIB", 7*60*60)
	start := time.Date(2026, 10, 25, 8, 0, 0, 0, jakarta)
	f := NewFake(start)

	// Act
	got := f.Now()

	// Assert
	if !got.Equal(start) || got.Location() != time.UTC {
		t.Errorf("got %s, want %s in UTC", got, start)
	}
}

func TestFakeAdvance(t *testing.T) {
	// Arrange
	start := time.Date(2026, 10, 25, 1, 0, 0, 0, time.UTC)
	f := NewFake(start)

	// Act
	f.Advance(15 * time.Minute)

	// Assert
	if want := start.Add(15 * time.Minute); !f.Now().Equal(want) {
		t.Errorf("got %s, want %s", f.Now(), want)
	}
}

func TestFakeSet(t *testing.T) {
	// Arrange
	f := NewFake(time.Date(2026, 10, 25, 1, 0, 0, 0, time.UTC))
	want := time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)

	// Act
	f.Set(want)

	// Assert
	if !f.Now().Equal(want) {
		t.Errorf("got %s, want %s", f.Now(), want)
	}
}
