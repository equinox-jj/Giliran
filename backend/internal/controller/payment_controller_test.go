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
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

type fakePayments struct {
	view    service.PaymentView
	board   []service.PaymentView
	summary repository.PaymentSummary
	err     error

	called     string
	gotGroup   uuid.UUID
	gotPayment uuid.UUID
	gotReason  string
	gotMethod  model.PaymentMethod
	gotNote    *string
	gotData    []byte
}

func (f *fakePayments) Board(_ context.Context, groupID, _, _ uuid.UUID) ([]service.PaymentView, repository.PaymentSummary, error) {
	f.called, f.gotGroup = "board", groupID
	return f.board, f.summary, f.err
}

func (f *fakePayments) Get(_ context.Context, groupID, paymentID, _ uuid.UUID) (service.PaymentDetail, error) {
	f.called, f.gotGroup, f.gotPayment = "get", groupID, paymentID
	d := service.PaymentDetail{PaymentView: f.view, Proofs: []service.Proof{}}
	if f.view.CurrentProof != nil {
		d.Proofs = append(d.Proofs, *f.view.CurrentProof)
	}
	return d, f.err
}

func (f *fakePayments) UploadProof(_ context.Context, groupID, paymentID, _ uuid.UUID, data []byte) (service.PaymentView, error) {
	f.called, f.gotGroup, f.gotPayment, f.gotData = "upload", groupID, paymentID, data
	return f.view, f.err
}

func (f *fakePayments) Approve(_ context.Context, groupID, paymentID, _ uuid.UUID) (service.PaymentView, error) {
	f.called, f.gotGroup, f.gotPayment = "approve", groupID, paymentID
	return f.view, f.err
}

func (f *fakePayments) Reject(_ context.Context, groupID, paymentID, _ uuid.UUID, reason string) (service.PaymentView, error) {
	f.called, f.gotGroup, f.gotPayment, f.gotReason = "reject", groupID, paymentID, reason
	return f.view, f.err
}

func (f *fakePayments) MarkPaid(_ context.Context, groupID, paymentID, _ uuid.UUID, method model.PaymentMethod, note *string) (service.PaymentView, error) {
	f.called, f.gotGroup, f.gotPayment, f.gotMethod, f.gotNote = "mark_paid", groupID, paymentID, method, note
	return f.view, f.err
}

// fakeRunner runs fn like IdempotencyService, without a database: a stored
// response is replayed and err fails the request before fn.
type fakeRunner struct {
	stored *service.StoredResponse
	err    error

	got service.IdempotentRequest
}

func (f *fakeRunner) Run(ctx context.Context, req service.IdempotentRequest, fn func(ctx context.Context) (service.StoredResponse, error)) (service.StoredResponse, bool, error) {
	f.got = req
	if f.err != nil {
		return service.StoredResponse{}, false, f.err
	}
	if f.stored != nil {
		return *f.stored, true, nil
	}
	resp, err := fn(ctx)
	return resp, false, err
}

func newPaymentApp(payments PaymentService, runner IdempotencyRunner) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &PaymentController{payments: payments}
	idem := (&Idempotency{runner: runner}).Handle
	g := app.Group("/api/v1/groups/:group_id", middleware.Auth(testTokens))
	g.Get("/periods/:period_id/payments", h.Board)
	g.Get("/payments/:payment_id", h.Get)
	g.Post("/payments/:payment_id/proofs", idem, h.UploadProof)
	g.Post("/payments/:payment_id/approve", idem, h.Approve)
	g.Post("/payments/:payment_id/reject", idem, h.Reject)
	g.Post("/payments/:payment_id/mark-paid", idem, h.MarkPaid)
	return app
}

// testPayment is Budi's pending payment with a proof, as the payer sees it.
func testPayment() service.PaymentView {
	now := time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC)
	proofID := uuid.Must(uuid.NewV7())
	return service.PaymentView{
		Payment: model.Payment{
			ID: uuid.Must(uuid.NewV7()), PeriodID: uuid.Must(uuid.NewV7()), Amount: 150_000,
			Status: model.PaymentStatusPendingReview, CurrentProofID: &proofID, CreatedAt: now, UpdatedAt: now,
		},
		Member: testMember(false),
		CurrentProof: &service.Proof{
			PaymentProof: model.PaymentProof{ID: proofID, ContentType: model.ProofContentTypeJPEG, CreatedAt: now},
			URL:          "http://localhost:9000/giliran/proofs/a.jpg?X-Amz-Signature=x",
		},
		IsMine: true,
	}
}

// paymentPathOf is a payment route under a random group.
func paymentPathOf(paymentID uuid.UUID, action string) string {
	p := "/api/v1/groups/" + uuid.Must(uuid.NewV7()).String() + "/payments/" + paymentID.String()
	if action != "" {
		p += "/" + action
	}
	return p
}

// idempotent builds an authenticated JSON write with an Idempotency-Key.
func idempotent(t *testing.T, path, body string) *http.Request {
	t.Helper()
	req, _, _ := authed(t, http.MethodPost, path, body)
	req.Header.Set(HeaderIdempotencyKey, "0b6f5c1e-7a1d-4a51-9c2e-1d1d6f3f9a10")
	return req
}

// proofRequest builds a multipart proof upload; boundary is the multipart
// boundary, which clients pick at random.
func proofRequest(t *testing.T, path, boundary string, data []byte) *http.Request {
	t.Helper()
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	if err := w.SetBoundary(boundary); err != nil {
		t.Fatalf("SetBoundary: %v", err)
	}
	part, err := w.CreateFormFile("file", "bukti.png")
	if err != nil {
		t.Fatalf("CreateFormFile: %v", err)
	}
	if _, err := part.Write(data); err != nil {
		t.Fatalf("Write: %v", err)
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
	req.Header.Set(HeaderIdempotencyKey, "upload-key-0001")
	return req
}

func TestPaymentBoard(t *testing.T) {
	// Arrange
	other := testPayment()
	other.CurrentProof, other.IsMine = nil, false
	fake := &fakePayments{
		board:   []service.PaymentView{testPayment(), other},
		summary: repository.PaymentSummary{TotalCount: 2, PendingReviewCount: 2, ExpectedAmount: 300_000},
	}
	path := "/api/v1/groups/" + uuid.Must(uuid.NewV7()).String() + "/periods/" + uuid.Must(uuid.NewV7()).String() + "/payments"
	req, _, _ := authed(t, http.MethodGet, path, "")

	// Act
	resp, body := call(t, newPaymentApp(fake, &fakeRunner{}), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "board" {
		t.Fatalf("status %d, service called %q", resp.StatusCode, fake.called)
	}
	data := body["data"].([]any)
	if len(data) != 2 || data[1].(map[string]any)["current_proof"] != nil {
		t.Errorf("data %v", data)
	}
	if sum := body["meta"].(map[string]any)["summary"].(map[string]any); sum["expected_amount"] != float64(300_000) {
		t.Errorf("summary %v", sum)
	}
}

func TestPaymentGet(t *testing.T) {
	// Arrange
	fake := &fakePayments{view: testPayment()}
	req, _, _ := authed(t, http.MethodGet, paymentPathOf(fake.view.Payment.ID, ""), "")

	// Act
	resp, body := call(t, newPaymentApp(fake, &fakeRunner{}), req)

	// Assert
	data := body["data"].(map[string]any)
	if resp.StatusCode != 200 || fake.gotPayment != fake.view.Payment.ID || len(data["proofs"].([]any)) != 1 || data["is_mine"] != true {
		t.Fatalf("status %d, data %v", resp.StatusCode, data)
	}
}

func TestPaymentUploadProof(t *testing.T) {
	// Arrange
	fake := &fakePayments{view: testPayment()}
	path := paymentPathOf(fake.view.Payment.ID, "proofs")
	req := proofRequest(t, path, "boundary-one", []byte("png bytes"))

	// Act
	resp, body := call(t, newPaymentApp(fake, &fakeRunner{}), req)

	// Assert
	if resp.StatusCode != 201 || fake.called != "upload" || string(fake.gotData) != "png bytes" {
		t.Fatalf("status %d, service got %s %q, body %v", resp.StatusCode, fake.called, fake.gotData, body)
	}
	if loc := resp.Header.Get("Location"); loc != path[:len(path)-len("/proofs")] {
		t.Errorf("Location %q", loc)
	}
}

func TestPaymentApprove(t *testing.T) {
	// Arrange
	fake := &fakePayments{view: testPayment()}
	fake.view.Payment.Status = model.PaymentStatusPaid
	req := idempotent(t, paymentPathOf(fake.view.Payment.ID, "approve"), "")

	// Act
	resp, body := call(t, newPaymentApp(fake, &fakeRunner{}), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "approve" || body["data"].(map[string]any)["status"] != "paid" {
		t.Fatalf("status %d, service called %q, body %v", resp.StatusCode, fake.called, body)
	}
}

func TestPaymentReject(t *testing.T) {
	// Arrange
	fake := &fakePayments{view: testPayment()}
	req := idempotent(t, paymentPathOf(fake.view.Payment.ID, "reject"), `{"reason":"Nominal kurang."}`)

	// Act
	resp, _ := call(t, newPaymentApp(fake, &fakeRunner{}), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotReason != "Nominal kurang." {
		t.Fatalf("status %d, reason %q", resp.StatusCode, fake.gotReason)
	}
}

func TestPaymentMarkPaid(t *testing.T) {
	// Arrange
	fake := &fakePayments{view: testPayment()}
	req := idempotent(t, paymentPathOf(fake.view.Payment.ID, "mark-paid"), `{"method":"cash","note":"Tunai"}`)

	// Act
	resp, _ := call(t, newPaymentApp(fake, &fakeRunner{}), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotMethod != model.PaymentMethodCash || fake.gotNote == nil || *fake.gotNote != "Tunai" {
		t.Fatalf("status %d, method %q, note %v", resp.StatusCode, fake.gotMethod, fake.gotNote)
	}
}

func TestPaymentWriteValidation(t *testing.T) {
	// Arrange
	tests := []struct {
		name      string
		action    string
		body      string
		wantField string
	}{
		{"reject without reason", "reject", `{}`, "reason"},
		{"reject with short reason", "reject", `{"reason":"no"}`, "reason"},
		{"mark paid with unknown method", "mark-paid", `{"method":"gopay"}`, "method"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakePayments{}
			req := idempotent(t, paymentPathOf(uuid.Must(uuid.NewV7()), tt.action), tt.body)

			// Act
			resp, body := call(t, newPaymentApp(fake, &fakeRunner{}), req)

			// Assert
			if resp.StatusCode != 422 || fake.called != "" {
				t.Fatalf("status %d, service called %q", resp.StatusCode, fake.called)
			}
			if f := body["errors"].([]any)[0].(map[string]any); f["field"] != tt.wantField {
				t.Errorf("errors %v, want field %s", body["errors"], tt.wantField)
			}
		})
	}
}

func TestPaymentWriteErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"already reviewed", model.ErrPaymentAlreadyReviewed, 409, "payment_already_reviewed"},
		{"invalid state", model.ErrInvalidPaymentState, 409, "invalid_payment_state"},
		{"period not open", model.ErrPeriodNotOpen, 409, "period_not_open"},
		{"member", model.ErrForbiddenRole, 403, "forbidden_role"},
		{"unknown payment", model.ErrPaymentNotFound, 404, "payment_not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakePayments{err: tt.serviceErr}
			req := idempotent(t, paymentPathOf(uuid.Must(uuid.NewV7()), "approve"), "")

			// Act
			resp, body := call(t, newPaymentApp(fake, &fakeRunner{}), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestIdempotencyKeyHeaderChecked(t *testing.T) {
	// Arrange
	tests := []struct {
		name     string
		key      string
		wantCode model.FieldCode
	}{
		{"missing", "", model.FieldRequired},
		{"too short", "abc", model.FieldMinLength},
		{"too long", string(bytes.Repeat([]byte("k"), 101)), model.FieldMaxLength},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake, runner := &fakePayments{}, &fakeRunner{}
			req, _, _ := authed(t, http.MethodPost, paymentPathOf(uuid.Must(uuid.NewV7()), "approve"), "")
			if tt.key != "" {
				req.Header.Set(HeaderIdempotencyKey, tt.key)
			}

			// Act
			resp, body := call(t, newPaymentApp(fake, runner), req)

			// Assert
			if resp.StatusCode != 422 || fake.called != "" {
				t.Fatalf("status %d, service called %q", resp.StatusCode, fake.called)
			}
			if f := body["errors"].([]any)[0].(map[string]any); f["field"] != HeaderIdempotencyKey || f["code"] != string(tt.wantCode) {
				t.Errorf("errors %v", body["errors"])
			}
		})
	}
}

func TestIdempotencyReplaysStoredResponse(t *testing.T) {
	// Arrange
	fake := &fakePayments{}
	stored := `{"data":{"id":"0192e2a4-0000-7000-8000-000000000001"}}`
	runner := &fakeRunner{stored: &service.StoredResponse{Status: 200, Body: []byte(stored)}}
	req := idempotent(t, paymentPathOf(uuid.Must(uuid.NewV7()), "approve"), "")

	// Act
	resp, err := newPaymentApp(fake, runner).Test(req)

	// Assert
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	var body bytes.Buffer
	_, _ = body.ReadFrom(resp.Body)
	if resp.StatusCode != 200 || body.String() != stored || resp.Header.Get(HeaderIdempotentReplayed) != "true" || fake.called != "" {
		t.Errorf("status %d, body %s, replayed %q, service called %q", resp.StatusCode, body.String(), resp.Header.Get(HeaderIdempotentReplayed), fake.called)
	}
}

func TestIdempotencyKeyReused(t *testing.T) {
	// Arrange
	runner := &fakeRunner{err: model.ErrIdempotencyKeyReused}
	req := idempotent(t, paymentPathOf(uuid.Must(uuid.NewV7()), "approve"), "")

	// Act
	resp, body := call(t, newPaymentApp(&fakePayments{}, runner), req)

	// Assert
	if resp.StatusCode != 422 || body["code"] != "idempotency_key_reused" {
		t.Errorf("status %d, code %v", resp.StatusCode, body["code"])
	}
}

func TestIdempotencyRequestHash(t *testing.T) {
	// Arrange
	paymentID := uuid.Must(uuid.NewV7())
	path := paymentPathOf(paymentID, "proofs")
	hashOf := func(req *http.Request) service.IdempotentRequest {
		t.Helper()
		runner := &fakeRunner{}
		if _, err := newPaymentApp(&fakePayments{view: testPayment()}, runner).Test(req); err != nil {
			t.Fatalf("app.Test: %v", err)
		}
		return runner.got
	}
	tests := []struct {
		name string
		a, b func() *http.Request
		same bool
	}{
		{"multipart retry with a new boundary",
			func() *http.Request { return proofRequest(t, path, "boundary-one", []byte("png")) },
			func() *http.Request { return proofRequest(t, path, "boundary-two", []byte("png")) }, true},
		{"multipart with another file",
			func() *http.Request { return proofRequest(t, path, "boundary-one", []byte("png")) },
			func() *http.Request { return proofRequest(t, path, "boundary-one", []byte("jpg")) }, false},
		{"json with another body",
			func() *http.Request {
				return idempotent(t, paymentPathOf(paymentID, "reject"), `{"reason":"Buram"}`)
			},
			func() *http.Request {
				return idempotent(t, paymentPathOf(paymentID, "reject"), `{"reason":"Kurang"}`)
			}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := hashOf(tt.a())

			// Act
			b := hashOf(tt.b())

			// Assert
			if (a.Hash == b.Hash) != tt.same {
				t.Errorf("hashes %s and %s, want same=%v", a.Hash, b.Hash, tt.same)
			}
			if a.Method != http.MethodPost || a.Key == "" {
				t.Errorf("request %+v", a)
			}
		})
	}
}
