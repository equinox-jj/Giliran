package controller

import (
	"context"
	"encoding/json"
	"net/http"
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

type fakeTransparency struct {
	page        service.ActivityPage
	obligations []service.Obligation
	err         error

	gotCursor string
	gotLimit  int
}

func (f *fakeTransparency) Activity(_ context.Context, _, _ uuid.UUID, cursor string, limit int) (service.ActivityPage, error) {
	f.gotCursor, f.gotLimit = cursor, limit
	return f.page, f.err
}

func (f *fakeTransparency) Obligations(context.Context, uuid.UUID, uuid.UUID) ([]service.Obligation, error) {
	return f.obligations, f.err
}

type fakeReminders struct {
	result service.ReminderResult
	recap  service.Recap
	err    error

	gotMembers []uuid.UUID
}

func (f *fakeReminders) Send(_ context.Context, _, _, _ uuid.UUID, memberIDs []uuid.UUID) (service.ReminderResult, error) {
	f.gotMembers = memberIDs
	return f.result, f.err
}

func (f *fakeReminders) Recap(context.Context, uuid.UUID, uuid.UUID, uuid.UUID) (service.Recap, error) {
	return f.recap, f.err
}

type fakeAccount struct {
	err    error
	gotPIN string
}

func (f *fakeAccount) Delete(_ context.Context, _ uuid.UUID, pin string) error {
	f.gotPIN = pin
	return f.err
}

func newTransparencyApp(tr TransparencyService, rem ReminderService, acc AccountService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	auth := middleware.Auth(testTokens)
	th := &TransparencyController{transparency: tr}
	rh := &ReminderController{reminders: rem}
	mh := &MeController{account: acc}
	app.Post("/api/v1/me/deletion", auth, mh.DeleteAccount)
	g := app.Group("/api/v1/groups/:group_id", auth)
	g.Get("/activity", th.Activity)
	g.Get("/obligations", th.Obligations)
	g.Post("/periods/:period_id/reminders", rh.Send)
	g.Get("/periods/:period_id/recap", rh.Recap)
	return app
}

func TestActivityList(t *testing.T) {
	// Arrange
	budi := testMember(false)
	paymentID := uuid.Must(uuid.NewV7())
	next := "MTIz"
	fake := &fakeTransparency{page: service.ActivityPage{
		Entries: []service.ActivityEntry{{
			Log: model.ActivityLog{
				ID: 123, Action: model.ActionPaymentApproved, EntityType: model.EntityTypePayment, EntityID: &paymentID,
				Before: json.RawMessage(`{"status":"pending_review"}`), After: json.RawMessage(`{"status":"paid"}`),
				CreatedAt: time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC),
			},
			Actor:   &service.UserRef{ID: uuid.Must(uuid.NewV7()), Name: "Rina"},
			Subject: &budi,
		}, {
			Log: model.ActivityLog{
				ID: 122, ActorType: model.ActorTypeSystem, Action: model.ActionPeriodOpened, EntityType: model.EntityTypePeriod,
				EntityID: &paymentID, CreatedAt: time.Date(2026, 10, 26, 1, 0, 0, 0, time.UTC),
			},
		}},
		NextCursor: &next,
	}}
	req, _, _ := authed(t, http.MethodGet, groupPath("/activity?limit=2&cursor=abc"), "")

	// Act
	resp, body := call(t, newTransparencyApp(fake, nil, nil), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotLimit != 2 || fake.gotCursor != "abc" {
		t.Fatalf("status %d, service got limit %d cursor %q", resp.StatusCode, fake.gotLimit, fake.gotCursor)
	}
	data := body["data"].([]any)
	first, second := data[0].(map[string]any), data[1].(map[string]any)
	if first["id"] != "123" || first["subject"].(map[string]any)["slot_no"] != float64(3) || first["after"].(map[string]any)["status"] != "paid" {
		t.Errorf("first entry %v", first)
	}
	if second["actor"] != nil || second["subject"] != nil || second["before"] != nil {
		t.Errorf("system entry %v", second)
	}
	meta := body["meta"].(map[string]any)
	if meta["next_cursor"] != next || meta["has_more"] != true {
		t.Errorf("meta %v", meta)
	}
}

func TestActivityDefaultsAndLastPage(t *testing.T) {
	// Arrange
	fake := &fakeTransparency{}
	req, _, _ := authed(t, http.MethodGet, groupPath("/activity"), "")

	// Act
	resp, body := call(t, newTransparencyApp(fake, nil, nil), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotLimit != service.DefaultActivityLimit {
		t.Fatalf("status %d, limit %d", resp.StatusCode, fake.gotLimit)
	}
	if data := body["data"].([]any); len(data) != 0 {
		t.Errorf("data %v", data)
	}
	if meta := body["meta"].(map[string]any); meta["has_more"] != false || meta["next_cursor"] != nil {
		t.Errorf("meta %v", meta)
	}
}

func TestActivityBadLimit(t *testing.T) {
	// Arrange
	req, _, _ := authed(t, http.MethodGet, groupPath("/activity?limit=ten"), "")

	// Act
	resp, body := call(t, newTransparencyApp(&fakeTransparency{}, nil, nil), req)

	// Assert
	if resp.StatusCode != 400 || body["code"] != "invalid_pagination" {
		t.Errorf("status %d code %v", resp.StatusCode, body["code"])
	}
}

func TestObligationsList(t *testing.T) {
	// Arrange
	fake := &fakeTransparency{obligations: []service.Obligation{{
		Member: testMember(false), WonPeriodNo: 1, RemainingCount: 3, RemainingAmount: 450_000, OverdueCount: 1, OverdueAmount: 150_000,
	}}}
	req, _, _ := authed(t, http.MethodGet, groupPath("/obligations"), "")

	// Act
	resp, body := call(t, newTransparencyApp(fake, nil, nil), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	o := body["data"].([]any)[0].(map[string]any)
	if o["remaining_amount"] != float64(450_000) || o["overdue_count"] != float64(1) || o["won_period_no"] != float64(1) {
		t.Errorf("obligation %v", o)
	}
}

func TestRemindersSend(t *testing.T) {
	// Arrange
	phone := "+6281299998888"
	memberID := uuid.Must(uuid.NewV7())
	tests := []struct {
		name        string
		body        string
		wantMembers int
	}{
		{"every unpaid member", "", 0},
		{"chosen members", `{"member_ids":["` + memberID.String() + `"]}`, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeReminders{result: service.ReminderResult{SentCount: 2, Skipped: []service.ReminderSkip{
				{Member: testMember(false), Reason: service.ReminderSkipNoDevice, WhatsAppPhone: &phone},
			}}}
			req, _, _ := authed(t, http.MethodPost, groupPath("/periods/"+uuid.Must(uuid.NewV7()).String()+"/reminders"), tt.body)
			req.Header.Set("Idempotency-Key", "reminders-key-1")

			// Act
			resp, body := call(t, newTransparencyApp(nil, fake, nil), req)

			// Assert
			if resp.StatusCode != 200 || len(fake.gotMembers) != tt.wantMembers {
				t.Fatalf("status %d, service got %v", resp.StatusCode, fake.gotMembers)
			}
			data := body["data"].(map[string]any)
			skip := data["skipped"].([]any)[0].(map[string]any)
			if data["sent_count"] != float64(2) || skip["reason"] != "no_device" || skip["whatsapp_phone"] != phone {
				t.Errorf("data %v", data)
			}
		})
	}
}

func TestRemindersSendInvalidMemberID(t *testing.T) {
	// Arrange
	req, _, _ := authed(t, http.MethodPost, groupPath("/periods/"+uuid.Must(uuid.NewV7()).String()+"/reminders"), `{"member_ids":["nope"]}`)
	req.Header.Set("Idempotency-Key", "reminders-key-1")

	// Act
	resp, body := call(t, newTransparencyApp(nil, &fakeReminders{}, nil), req)

	// Assert
	if resp.StatusCode != 422 || body["code"] != "validation_error" {
		t.Errorf("status %d code %v", resp.StatusCode, body["code"])
	}
}

func TestRecapGet(t *testing.T) {
	// Arrange
	bank, phone := "BCA", "+6281299998888"
	winner := testMember(false)
	fake := &fakeReminders{recap: service.Recap{
		Group: model.Group{Name: "Arisan RT 05", Amount: 150_000, TotalSlots: 4, BankName: &bank},
		Period: model.Period{
			PeriodNo: 2, DueDate: time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC), DrawDate: time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC),
		},
		Summary:    repository.PaymentSummary{TotalCount: 4, PaidCount: 3, CollectedAmount: 450_000, ExpectedAmount: 600_000},
		Unpaid:     []service.RecapUnpaid{{Member: testMember(false), WhatsAppPhone: &phone}},
		LastWinner: &winner,
	}}
	req, _, _ := authed(t, http.MethodGet, groupPath("/periods/"+uuid.Must(uuid.NewV7()).String()+"/recap"), "")

	// Act
	resp, body := call(t, newTransparencyApp(nil, fake, nil), req)

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("status %d", resp.StatusCode)
	}
	data := body["data"].(map[string]any)
	if data["group_name"] != "Arisan RT 05" || data["total_periods"] != float64(4) || data["due_date"] != "2026-12-01" ||
		data["payment_info"].(map[string]any)["bank_name"] != bank || data["last_winner"] == nil {
		t.Errorf("recap %v", data)
	}
}

func TestDeleteAccount(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"deleted", nil, 204, ""},
		{"blocked", model.ErrObligationsOutstanding, 409, "obligations_outstanding"},
		{"organizer", model.ErrOrganizerCannotLeave, 409, "organizer_cannot_leave"},
		{"locked", model.ErrPINLocked, 423, "pin_locked"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeAccount{err: tt.serviceErr}
			req, _, _ := authed(t, http.MethodPost, "/api/v1/me/deletion", `{"pin":"258046"}`)

			// Act
			resp, body := call(t, newTransparencyApp(nil, nil, fake), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || fake.gotPIN != "258046" {
				t.Fatalf("status %d, pin %q", resp.StatusCode, fake.gotPIN)
			}
			if tt.wantCode != "" && body["code"] != tt.wantCode {
				t.Errorf("code %v, want %s", body["code"], tt.wantCode)
			}
		})
	}
}
