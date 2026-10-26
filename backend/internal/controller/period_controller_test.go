package controller

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

type fakePeriods struct {
	periods []service.PeriodDetail
	err     error

	called    string
	gotGroup  uuid.UUID
	gotPeriod uuid.UUID
}

func (f *fakePeriods) List(_ context.Context, groupID, _ uuid.UUID) ([]service.PeriodDetail, error) {
	f.called, f.gotGroup = "list", groupID
	return f.periods, f.err
}

func (f *fakePeriods) Get(_ context.Context, groupID, periodID, _ uuid.UUID) (service.PeriodDetail, error) {
	f.called, f.gotGroup, f.gotPeriod = "get", groupID, periodID
	if f.err != nil {
		return service.PeriodDetail{}, f.err
	}
	return f.periods[0], nil
}

func newPeriodApp(periods PeriodService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &PeriodController{periods: periods}
	g := app.Group("/api/v1/groups/:group_id", middleware.Auth(testTokens))
	g.Get("/periods", h.List)
	g.Get("/periods/:period_id", h.Get)
	return app
}

// testPeriods is an open period 1 with a published hash and an upcoming
// period 2.
func testPeriods() []service.PeriodDetail {
	hash := strings.Repeat("ab", 32)
	now := time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC)
	return []service.PeriodDetail{
		{
			PeriodView: repository.PeriodView{Period: model.Period{
				ID: uuid.Must(uuid.NewV7()), PeriodNo: 1, Status: model.PeriodStatusOpen, SeedHash: &hash,
				DueDate: time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC), DrawDate: time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC),
				CreatedAt: now, UpdatedAt: now,
			}},
			Summary: &repository.PaymentSummary{TotalCount: 4, PaidCount: 1, UnpaidCount: 3, CollectedAmount: 150_000, ExpectedAmount: 600_000},
		},
		{
			PeriodView: repository.PeriodView{Period: model.Period{
				ID: uuid.Must(uuid.NewV7()), PeriodNo: 2, Status: model.PeriodStatusUpcoming,
				DueDate: time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC), DrawDate: time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC),
				CreatedAt: now, UpdatedAt: now,
			}},
		},
	}
}

func TestPeriodList(t *testing.T) {
	// Arrange
	fake := &fakePeriods{periods: testPeriods()}
	groupID := uuid.Must(uuid.NewV7())
	req, _, _ := authed(t, http.MethodGet, "/api/v1/groups/"+groupID.String()+"/periods", "")

	// Act
	resp, body := call(t, newPeriodApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "list" || fake.gotGroup != groupID {
		t.Fatalf("status %d, service got %s for %s", resp.StatusCode, fake.called, fake.gotGroup)
	}
	data := body["data"].([]any)
	open, upcoming := data[0].(map[string]any), data[1].(map[string]any)
	if open["seed_hash"] != strings.Repeat("ab", 32) || open["due_date"] != "2026-11-01" || open["payment_summary"].(map[string]any)["expected_amount"] != float64(600_000) {
		t.Errorf("open period %v", open)
	}
	if upcoming["seed_hash"] != nil || upcoming["payment_summary"] != nil || upcoming["winner"] != nil {
		t.Errorf("upcoming period %v", upcoming)
	}
	if _, ok := open["seed"]; ok {
		t.Error("period exposes its seed")
	}
}

func TestPeriodGet(t *testing.T) {
	// Arrange
	fake := &fakePeriods{periods: testPeriods()}
	groupID, periodID := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	req, _, _ := authed(t, http.MethodGet, "/api/v1/groups/"+groupID.String()+"/periods/"+periodID.String(), "")

	// Act
	resp, body := call(t, newPeriodApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotPeriod != periodID || body["data"].(map[string]any)["period_no"] != float64(1) {
		t.Fatalf("status %d, service got %s, body %v", resp.StatusCode, fake.gotPeriod, body)
	}
}

func TestPeriodGetErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		periodID   string
		serviceErr error
		wantCode   string
	}{
		{"bad id", "not-a-uuid", nil, "period_not_found"},
		{"unknown", uuid.Must(uuid.NewV7()).String(), model.ErrPeriodNotFound, "period_not_found"},
		{"non-member", uuid.Must(uuid.NewV7()).String(), model.ErrGroupNotFound, "group_not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakePeriods{err: tt.serviceErr}
			req, _, _ := authed(t, http.MethodGet, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String()+"/periods/"+tt.periodID, "")

			// Act
			resp, body := call(t, newPeriodApp(fake), req)

			// Assert
			if resp.StatusCode != 404 || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want 404 %s", resp.StatusCode, body["code"], tt.wantCode)
			}
		})
	}
}
