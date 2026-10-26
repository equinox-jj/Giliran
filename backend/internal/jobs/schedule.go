package jobs

import (
	"fmt"
	"time"

	"github.com/robfig/cron/v3"
)

// NewSchedule parses a standard five-field cron spec evaluated in loc, so
// "0 8 * * *" means 08:00 in APP_TIMEZONE wherever the worker runs.
func NewSchedule(spec string, loc *time.Location) (cron.Schedule, error) {
	s, err := cron.ParseStandard(spec)
	if err != nil {
		return nil, fmt.Errorf("cron %q: %w", spec, err)
	}
	if spec, ok := s.(*cron.SpecSchedule); ok {
		spec.Location = loc
	}
	return s, nil
}
