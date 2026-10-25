// Package clock is the app's source of "now". Services take a Clock instead of
// calling time.Now, so tests can pin draw dates, PIN lockouts, token expiry
// and reminders to a known instant.
package clock

import (
	"sync"
	"time"

	"go.uber.org/fx"
)

// Clock reports the current instant.
type Clock interface {
	Now() time.Time
}

// Module provides the system Clock.
var Module = fx.Module("clock", fx.Provide(func() Clock { return System{} }))

// System is the real clock. Now is in UTC, matching TIMESTAMPTZ storage.
type System struct{}

func (System) Now() time.Time {
	return time.Now().UTC()
}

// Fake is a Clock for tests that only moves when told to. It is safe for
// concurrent use.
type Fake struct {
	mu  sync.Mutex
	now time.Time
}

// NewFake returns a Fake stopped at now.
func NewFake(now time.Time) *Fake {
	return &Fake{now: now.UTC()}
}

func (f *Fake) Now() time.Time {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.now
}

// Set moves the clock to now.
func (f *Fake) Set(now time.Time) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.now = now.UTC()
}

// Advance moves the clock forward by d.
func (f *Fake) Advance(d time.Duration) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.now = f.now.Add(d)
}
