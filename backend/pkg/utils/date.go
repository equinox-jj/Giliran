package utils

import (
	"time"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// Business dates (start, due and draw dates) are calendar days in
// Asia/Jakarta. They are held as a time.Time at 00:00 UTC on that day, which
// is how pgx scans a DATE column, so values round-trip unchanged.

// Date returns the business date for year, month and day.
func Date(year int, month time.Month, day int) time.Time {
	return time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
}

// Today is the calendar day in loc (APP_TIMEZONE) at the instant now.
func Today(now time.Time, loc *time.Location) time.Time {
	y, m, d := now.In(loc).Date()
	return Date(y, m, d)
}

// DueDate is the due date of period periodNo (1-based) for a group whose first
// due date is start (BR-06). Weekly groups add 7 days per period. Monthly
// groups keep start's day of month, clamped to the last day of shorter
// months; the clamp never carries over, so Jan 31 gives Feb 28 then Mar 31.
func DueDate(start time.Time, periodType model.PeriodType, periodNo int) time.Time {
	offset := periodNo - 1
	if periodType == model.PeriodTypeWeekly {
		return start.AddDate(0, 0, 7*offset)
	}
	y, m, d := start.Date()
	first := Date(y, m+time.Month(offset), 1) // time.Date normalizes the month
	return Date(first.Year(), first.Month(), min(d, daysIn(first.Year(), first.Month())))
}

// daysIn is the number of days in month of year.
func daysIn(year int, month time.Month) int {
	return Date(year, month+1, 0).Day()
}
