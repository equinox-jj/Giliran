// Package web renders the public HTML pages served next to the API: the
// Bukti Kocok draw verification page.
package web

import (
	"embed"
	"html/template"
	"io"
	"time"
)

//go:embed templates/*.html
var files embed.FS

var templates = template.Must(template.New("").Funcs(template.FuncMap{
	"jakarta": func(t time.Time) string {
		return t.In(jakarta).Format("2 Jan 2006, 15:04 WIB")
	},
}).ParseFS(files, "templates/*.html"))

var jakarta = func() *time.Location {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		return time.FixedZone("WIB", 7*60*60)
	}
	return loc
}()

// DrawSlot is one slot on the verification page.
type DrawSlot struct {
	SlotNo      int16
	DisplayName string
	SlotID      string
	IsWinner    bool
}

// DrawPage is what draw_verify.html shows.
type DrawPage struct {
	GroupName           string
	PeriodNo            int16
	TotalPeriods        int16
	PeriodID            string
	Algorithm           string
	IsRandom            bool
	SeedHash            string
	Seed                string
	SeedHashPublishedAt *time.Time
	EligibleSlots       []DrawSlot
	Winner              DrawSlot
	DrawnAt             time.Time
	HashMatches         bool
	WinnerMatches       bool
	JSONURL             string
}

// RenderDraw writes the verification page for p.
func RenderDraw(w io.Writer, p DrawPage) error {
	return templates.ExecuteTemplate(w, "draw_verify.html", p)
}

// RenderDrawNotFound writes the page for an unknown verification code.
func RenderDrawNotFound(w io.Writer) error {
	return templates.ExecuteTemplate(w, "draw_not_found.html", nil)
}
