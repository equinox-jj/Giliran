package controller

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

type fakeDraws struct {
	view   service.DrawView
	public service.PublicDraw
	err    error

	called     string
	gotPeriod  uuid.UUID
	gotConfirm bool
	gotCode    string
}

func (f *fakeDraws) Get(_ context.Context, _, periodID, _ uuid.UUID) (service.DrawView, error) {
	f.called, f.gotPeriod = "get", periodID
	return f.view, f.err
}

func (f *fakeDraws) Run(_ context.Context, _, periodID, _ uuid.UUID, confirmIncomplete bool) (service.DrawView, error) {
	f.called, f.gotPeriod, f.gotConfirm = "run", periodID, confirmIncomplete
	return f.view, f.err
}

func (f *fakeDraws) Public(_ context.Context, code string) (service.PublicDraw, error) {
	f.called, f.gotCode = "public", code
	return f.public, f.err
}

func newDrawApp(draws DrawService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &DrawController{draws: draws}
	idem := (&Idempotency{runner: &fakeRunner{}}).Handle
	g := app.Group("/api/v1/groups/:group_id", middleware.Auth(testTokens))
	g.Get("/periods/:period_id/draw", h.Get)
	g.Post("/periods/:period_id/draw", idem, h.Run)
	app.Get("/api/v1/public/draws/:verification_code", h.Public)
	app.Get("/v/:verification_code", h.Page)
	return app
}

const testCode = "7H2K9QX4MP"

// testDrawn is a drawn random period 1 won by slot 2 of three.
func testDrawn() (service.DrawView, service.PublicDraw) {
	now := time.Date(2026, 11, 1, 3, 0, 0, 0, time.UTC)
	hash, seed, code := strings.Repeat("ab", 32), strings.Repeat("cd", 32), testCode
	slots := []service.DrawSlot{
		{SlotID: uuid.Must(uuid.NewV7()), SlotNo: 1, DisplayName: "Rina Susanti"},
		{SlotID: uuid.Must(uuid.NewV7()), SlotNo: 2, DisplayName: "Budi Santoso"},
		{SlotID: uuid.Must(uuid.NewV7()), SlotNo: 3, DisplayName: "Pak Darto"},
	}
	ids := []uuid.UUID{slots[0].SlotID, slots[1].SlotID, slots[2].SlotID}
	winner, drawnBy := slots[1], uuid.Must(uuid.NewV7())
	p := model.Period{
		ID: uuid.Must(uuid.NewV7()), PeriodNo: 1, Status: model.PeriodStatusDrawn, SeedHash: &hash, Seed: &seed,
		DrawAlgorithm: model.DrawAlgorithmHMACSHA256V1, EligibleSlotIDs: ids, WinnerSlotID: &winner.SlotID,
		VerificationCode: &code, DrawnAt: &now, DrawnBy: &drawnBy,
	}
	paid, total, url := 3, 3, "https://giliran.monai.my.id/v/"+code
	view := service.DrawView{
		Period: p, Method: model.DrawMethodRandom, EligibleSlots: slots, Winner: &winner,
		DrawnBy: &service.UserRef{ID: drawnBy, Name: "Rina Susanti"}, PaidCount: &paid, TotalCount: &total, VerifyURL: &url,
	}
	masked := []service.DrawSlot{
		{SlotID: slots[0].SlotID, SlotNo: 1, DisplayName: "Rina S."},
		{SlotID: slots[1].SlotID, SlotNo: 2, DisplayName: "Budi S."},
		{SlotID: slots[2].SlotID, SlotNo: 3, DisplayName: "Pak D."},
	}
	published := now.Add(-30 * 24 * time.Hour)
	public := service.PublicDraw{
		GroupName: "Arisan RT 05", PeriodNo: 1, TotalPeriods: 3, PeriodID: p.ID, Algorithm: p.DrawAlgorithm,
		SeedHash: &hash, Seed: &seed, SeedHashPublishedAt: &published, EligibleSlots: masked, Winner: masked[1],
		DrawnAt: now, HashMatches: true, WinnerMatches: true, VerificationCode: code,
	}
	return view, public
}

func drawPathOf(periodID uuid.UUID) string {
	return "/api/v1/groups/" + uuid.Must(uuid.NewV7()).String() + "/periods/" + periodID.String() + "/draw"
}

func TestDrawGet(t *testing.T) {
	// Arrange
	view, _ := testDrawn()
	fake := &fakeDraws{view: view}
	req, _, _ := authed(t, http.MethodGet, drawPathOf(view.Period.ID), "")

	// Act
	resp, body := call(t, newDrawApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotPeriod != view.Period.ID {
		t.Fatalf("status %d, service got %s", resp.StatusCode, fake.gotPeriod)
	}
	data := body["data"].(map[string]any)
	if data["status"] != "drawn" || data["seed"] != strings.Repeat("cd", 32) || data["winner"].(map[string]any)["slot_no"] != float64(2) {
		t.Errorf("draw %v", data)
	}
	if len(data["eligible_slots"].([]any)) != 3 || data["paid_count_at_draw"] != float64(3) || data["verification_code"] != testCode {
		t.Errorf("draw %v", data)
	}
}

func TestDrawGetBeforeDraw(t *testing.T) {
	// Arrange
	hash := strings.Repeat("ab", 32)
	p := model.Period{ID: uuid.Must(uuid.NewV7()), PeriodNo: 1, Status: model.PeriodStatusOpen, SeedHash: &hash, DrawAlgorithm: model.DrawAlgorithmHMACSHA256V1}
	fake := &fakeDraws{view: service.DrawView{Period: p, Method: model.DrawMethodRandom, EligibleSlots: []service.DrawSlot{}}}
	req, _, _ := authed(t, http.MethodGet, drawPathOf(p.ID), "")

	// Act
	resp, body := call(t, newDrawApp(fake), req)

	// Assert
	data := body["data"].(map[string]any)
	if resp.StatusCode != 200 || data["status"] != "committed" || data["seed"] != nil || data["seed_hash"] != hash || data["winner"] != nil {
		t.Errorf("status %d, draw %v", resp.StatusCode, data)
	}
	if slots, ok := data["eligible_slots"].([]any); !ok || len(slots) != 0 {
		t.Errorf("eligible_slots %v, want []", data["eligible_slots"])
	}
}

func TestDrawRun(t *testing.T) {
	// Arrange
	tests := []struct {
		name        string
		body        string
		wantConfirm bool
	}{
		{"no body", "", false},
		{"confirm incomplete", `{"confirm_incomplete":true}`, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			view, _ := testDrawn()
			fake := &fakeDraws{view: view}
			path := drawPathOf(view.Period.ID)
			req := idempotent(t, path, tt.body)

			// Act
			resp, body := call(t, newDrawApp(fake), req)

			// Assert
			if resp.StatusCode != 201 || fake.called != "run" || fake.gotConfirm != tt.wantConfirm {
				t.Fatalf("status %d, service %s confirm %v", resp.StatusCode, fake.called, fake.gotConfirm)
			}
			if resp.Header.Get(fiber.HeaderLocation) != path || body["data"].(map[string]any)["status"] != "drawn" {
				t.Errorf("location %q, body %v", resp.Header.Get(fiber.HeaderLocation), body)
			}
		})
	}
}

func TestDrawRunErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"too early", model.ErrDrawTooEarly, 409, "draw_too_early"},
		{"already drawn", model.ErrDrawAlreadyDone, 409, "draw_already_done"},
		{"payments incomplete", model.ErrPaymentsIncomplete.WithExtensions(map[string]any{"paid_count": 8, "total_count": 10}), 409, "payments_incomplete"},
		{"member", model.ErrForbiddenRole, 403, "forbidden_role"},
		{"non-member", model.ErrGroupNotFound, 404, "group_not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeDraws{err: tt.serviceErr}
			req := idempotent(t, drawPathOf(uuid.Must(uuid.NewV7())), "")

			// Act
			resp, body := call(t, newDrawApp(fake), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestDrawRunPaymentsIncompleteCarriesCounts(t *testing.T) {
	// Arrange
	fake := &fakeDraws{err: model.ErrPaymentsIncomplete.WithExtensions(map[string]any{"paid_count": 8, "total_count": 10})}
	req := idempotent(t, drawPathOf(uuid.Must(uuid.NewV7())), "")

	// Act
	_, body := call(t, newDrawApp(fake), req)

	// Assert
	if body["paid_count"] != float64(8) || body["total_count"] != float64(10) {
		t.Errorf("problem %v", body)
	}
}

func TestDrawRunRequiresIdempotencyKey(t *testing.T) {
	// Arrange
	fake := &fakeDraws{}
	req, _, _ := authed(t, http.MethodPost, drawPathOf(uuid.Must(uuid.NewV7())), "")

	// Act
	resp, body := call(t, newDrawApp(fake), req)

	// Assert
	if resp.StatusCode != 422 || body["code"] != "validation_error" || fake.called != "" {
		t.Errorf("status %d code %v, service %q", resp.StatusCode, body["code"], fake.called)
	}
}

func TestDrawPublic(t *testing.T) {
	// Arrange
	_, public := testDrawn()
	fake := &fakeDraws{public: public}
	req := httptest.NewRequest(http.MethodGet, "/api/v1/public/draws/"+testCode, nil)

	// Act
	resp, body := call(t, newDrawApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotCode != testCode {
		t.Fatalf("status %d, service got %q", resp.StatusCode, fake.gotCode)
	}
	data := body["data"].(map[string]any)
	if data["hash_matches"] != true || data["recomputed_winner_matches"] != true || data["winner"].(map[string]any)["display_name"] != "Budi S." {
		t.Errorf("public draw %v", data)
	}
}

func TestDrawPublicNotFound(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		code       string
		serviceErr error
	}{
		{"unknown", "ZZZZZZZZZZ", model.ErrDrawNotFound},
		{"malformed", "abc", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeDraws{err: tt.serviceErr}
			req := httptest.NewRequest(http.MethodGet, "/api/v1/public/draws/"+tt.code, nil)

			// Act
			resp, err := newDrawApp(fake).Test(req)

			// Assert
			if err != nil {
				t.Fatal(err)
			}
			if resp.StatusCode != 404 || !strings.HasPrefix(resp.Header.Get(fiber.HeaderContentType), "application/problem+json") {
				t.Errorf("status %d, type %q", resp.StatusCode, resp.Header.Get(fiber.HeaderContentType))
			}
		})
	}
}

func TestDrawPage(t *testing.T) {
	// Arrange
	_, public := testDrawn()
	fake := &fakeDraws{public: public}
	req := httptest.NewRequest(http.MethodGet, "/v/"+testCode, nil)

	// Act
	resp, err := newDrawApp(fake).Test(req)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	b, _ := io.ReadAll(resp.Body)
	page := string(b)
	if resp.StatusCode != 200 || !strings.HasPrefix(resp.Header.Get(fiber.HeaderContentType), "text/html") {
		t.Fatalf("status %d, type %q", resp.StatusCode, resp.Header.Get(fiber.HeaderContentType))
	}
	for _, want := range []string{"Arisan RT 05", "Budi S.", strings.Repeat("cd", 32), public.PeriodID.String(), "/api/v1/public/draws/" + testCode} {
		if !strings.Contains(page, want) {
			t.Errorf("page lacks %q", want)
		}
	}
	if strings.Contains(page, "Budi Santoso") {
		t.Error("page shows a full name")
	}
}

func TestDrawPageNotFound(t *testing.T) {
	// Arrange
	fake := &fakeDraws{err: model.ErrDrawNotFound}
	req := httptest.NewRequest(http.MethodGet, "/v/ZZZZZZZZZZ", nil)

	// Act
	resp, err := newDrawApp(fake).Test(req)

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 404 || !strings.HasPrefix(resp.Header.Get(fiber.HeaderContentType), "text/html") {
		t.Errorf("status %d, type %q", resp.StatusCode, resp.Header.Get(fiber.HeaderContentType))
	}
}
