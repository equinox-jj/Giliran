package controller

import (
	"bytes"
	"context"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
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

type fakePayouts struct {
	view service.PayoutView
	err  error

	called    string
	gotPeriod uuid.UUID
	gotProof  []byte
	gotNote   *string
}

func (f *fakePayouts) Get(_ context.Context, _, periodID, _ uuid.UUID) (service.PayoutView, error) {
	f.called, f.gotPeriod = "get", periodID
	return f.view, f.err
}

func (f *fakePayouts) Record(_ context.Context, _, periodID, _ uuid.UUID, proof []byte, note *string) (service.PayoutView, error) {
	f.called, f.gotPeriod, f.gotProof, f.gotNote = "record", periodID, proof, note
	return f.view, f.err
}

func (f *fakePayouts) Confirm(_ context.Context, _, periodID, _ uuid.UUID) (service.PayoutView, error) {
	f.called, f.gotPeriod = "confirm", periodID
	return f.view, f.err
}

func newPayoutApp(payouts PayoutService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &PayoutController{payouts: payouts}
	idem := (&Idempotency{runner: &fakeRunner{}}).Handle
	g := app.Group("/api/v1/groups/:group_id", middleware.Auth(testTokens))
	g.Get("/periods/:period_id/payout", h.Get)
	g.Post("/periods/:period_id/payout", idem, h.Record)
	g.Post("/periods/:period_id/payout/confirm", idem, h.Confirm)
	return app
}

func testPayout() service.PayoutView {
	now := time.Date(2026, 11, 2, 3, 0, 0, 0, time.UTC)
	note, url := "Transfer BCA", "http://localhost:9000/giliran/payouts/a.jpg?X-Amz-Signature=x"
	return service.PayoutView{
		Payout: model.Payout{
			ID: uuid.Must(uuid.NewV7()), PeriodID: uuid.Must(uuid.NewV7()), Amount: 600_000, Note: &note,
			RecordedBy: uuid.Must(uuid.NewV7()), RecordedAt: now,
		},
		Winner:     testMember(false),
		RecordedBy: service.UserRef{ID: uuid.Must(uuid.NewV7()), Name: "Rina Susanti"},
		ProofURL:   &url,
	}
}

func payoutPathOf(periodID uuid.UUID, action string) string {
	p := "/api/v1/groups/" + uuid.Must(uuid.NewV7()).String() + "/periods/" + periodID.String() + "/payout"
	if action != "" {
		p += "/" + action
	}
	return p
}

// payoutRequest builds a multipart payout record with an optional file and
// note.
func payoutRequest(t *testing.T, path string, file []byte, note *string) *http.Request {
	t.Helper()
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	if file != nil {
		part, err := w.CreateFormFile("file", "transfer.png")
		if err != nil {
			t.Fatalf("CreateFormFile: %v", err)
		}
		if _, err := part.Write(file); err != nil {
			t.Fatalf("Write: %v", err)
		}
	}
	if note != nil {
		if err := w.WriteField("note", *note); err != nil {
			t.Fatalf("WriteField: %v", err)
		}
	}
	if err := w.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}
	token, _, err := testTokens.Issue(uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7()))
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, path, &body)
	req.Header.Set(fiber.HeaderContentType, w.FormDataContentType())
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
	req.Header.Set(HeaderIdempotencyKey, "payout-key-0001")
	return req
}

func TestPayoutGet(t *testing.T) {
	// Arrange
	v := testPayout()
	fake := &fakePayouts{view: v}
	req, _, _ := authed(t, http.MethodGet, payoutPathOf(v.Payout.PeriodID, ""), "")

	// Act
	resp, body := call(t, newPayoutApp(fake), req)

	// Assert
	data := body["data"].(map[string]any)
	if resp.StatusCode != 200 || data["amount"] != float64(600_000) || data["winner"].(map[string]any)["display_name"] != "Ani" {
		t.Errorf("status %d, payout %v", resp.StatusCode, data)
	}
}

func TestPayoutGetNotRecorded(t *testing.T) {
	// Arrange
	fake := &fakePayouts{err: model.ErrNotFound.WithDetail("No payout is recorded for this period.")}
	req, _, _ := authed(t, http.MethodGet, payoutPathOf(uuid.Must(uuid.NewV7()), ""), "")

	// Act
	resp, body := call(t, newPayoutApp(fake), req)

	// Assert
	if resp.StatusCode != 404 || body["code"] != "not_found" {
		t.Errorf("status %d code %v", resp.StatusCode, body["code"])
	}
}

func TestPayoutRecord(t *testing.T) {
	// Arrange
	note := "Transfer BCA"
	tests := []struct {
		name      string
		file      []byte
		note      *string
		wantProof bool
	}{
		{"with proof and note", []byte("png bytes"), &note, true},
		{"empty form", nil, nil, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakePayouts{view: testPayout()}
			periodID := uuid.Must(uuid.NewV7())
			req := payoutRequest(t, payoutPathOf(periodID, ""), tt.file, tt.note)

			// Act
			resp, _ := call(t, newPayoutApp(fake), req)

			// Assert
			if resp.StatusCode != 201 || fake.called != "record" || fake.gotPeriod != periodID {
				t.Fatalf("status %d, service %s for %s", resp.StatusCode, fake.called, fake.gotPeriod)
			}
			if (fake.gotProof != nil) != tt.wantProof || (fake.gotNote != nil) != (tt.note != nil) {
				t.Errorf("proof %v note %v", fake.gotProof, fake.gotNote)
			}
		})
	}
}

func TestPayoutRecordErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"already recorded", model.ErrPayoutAlreadyRecorded, 409, "payout_already_recorded"},
		{"not drawn", model.ErrPeriodNotOpen, 409, "period_not_open"},
		{"member", model.ErrForbiddenRole, 403, "forbidden_role"},
		{"too large", model.ErrFileTooLarge, 413, "file_too_large"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakePayouts{err: tt.serviceErr}
			req := payoutRequest(t, payoutPathOf(uuid.Must(uuid.NewV7()), ""), nil, nil)

			// Act
			resp, body := call(t, newPayoutApp(fake), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestPayoutConfirm(t *testing.T) {
	// Arrange
	v := testPayout()
	now := time.Date(2026, 11, 3, 3, 0, 0, 0, time.UTC)
	v.Payout.ConfirmedAt = &now
	fake := &fakePayouts{view: v}
	req := idempotent(t, payoutPathOf(v.Payout.PeriodID, "confirm"), "")

	// Act
	resp, body := call(t, newPayoutApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "confirm" || body["data"].(map[string]any)["confirmed_at"] == nil {
		t.Errorf("status %d, service %s, body %v", resp.StatusCode, fake.called, body)
	}
}
