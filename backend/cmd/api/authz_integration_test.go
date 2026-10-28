//go:build integration

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/fx"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/controller"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

// memStore keeps uploaded objects in memory instead of MinIO.
type memStore struct {
	mu      sync.Mutex
	objects map[string][]byte
}

func (s *memStore) Put(_ context.Context, key, _ string, r io.Reader, _ int64) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.objects[key] = data
	return nil
}

func (s *memStore) Delete(_ context.Context, key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.objects, key)
	return nil
}

func (s *memStore) PresignGet(_ context.Context, key string) (string, error) {
	return "https://files.test/" + key, nil
}

// sweepApp is the real API graph (config, services, controllers, routes and
// middleware) on a test database, with MinIO faked.
type sweepApp struct {
	app     *fiber.App
	tokens  *security.TokenIssuer
	groups  *service.GroupService
	members *service.MemberService
	leaves  *service.LeaveService
	owners  *service.OwnershipService
	pays    *service.PaymentService
	pool    *pgxpool.Pool
}

func newSweepApp(t *testing.T) sweepApp {
	t.Helper()
	db := integration.NewDB(t)
	t.Setenv("APP_ENV", "development")
	t.Setenv("APP_PUBLIC_BASE_URL", "https://giliran.test")
	t.Setenv("LOG_LEVEL", "error")
	t.Setenv("DATABASE_URL", db.Config().ConnString())
	t.Setenv("JWT_SECRET", strings.Repeat("s", 48))
	t.Setenv("OTP_SECRET", strings.Repeat("o", 48))
	t.Setenv("MINIO_ENDPOINT", "minio.test:9000")
	t.Setenv("MINIO_ACCESS_KEY", "test")
	t.Setenv("MINIO_SECRET_KEY", "test-secret")
	for _, k := range []string{"RATE_LIMIT_OTP_MAX", "RATE_LIMIT_PIN_MAX", "RATE_LIMIT_WRITE_MAX", "RATE_LIMIT_PUBLIC_MAX"} {
		t.Setenv(k, "100000")
	}

	var s sweepApp
	// Not started: routes are registered when the graph is built, and the
	// requests go through app.Test, so nothing listens on a port.
	app := fx.New(
		core(),
		fx.Provide(func() storage.Storage { return &memStore{objects: map[string][]byte{}} }),
		fx.Populate(&s.app, &s.tokens, &s.groups, &s.members, &s.leaves, &s.owners, &s.pays, &s.pool),
		fx.NopLogger,
	)
	if err := app.Err(); err != nil {
		t.Fatalf("fx: %v", err)
	}
	t.Cleanup(s.pool.Close)
	return s
}

// sweepFixture is a started three-slot group: organizer, member and guest,
// with a pending leave request from the member and a pending ownership
// offer to them.
type sweepFixture struct {
	organizer, member, outsider uuid.UUID
	params                      map[string]string
}

func newSweepFixture(t *testing.T, s sweepApp) sweepFixture {
	t.Helper()
	ctx := context.Background()
	f := sweepFixture{organizer: uuid.Must(uuid.NewV7()), member: uuid.Must(uuid.NewV7()), outsider: uuid.Must(uuid.NewV7())}
	for id, phone := range map[uuid.UUID]string{f.organizer: "+6281234567890", f.member: "+6281298765432", f.outsider: "+6281211112222"} {
		if _, err := s.pool.Exec(ctx, `INSERT INTO users (id, phone, name) VALUES ($1, $2, 'Anggota')`, id, phone); err != nil {
			t.Fatalf("insert user: %v", err)
		}
	}
	jakarta, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		t.Fatalf("LoadLocation: %v", err)
	}
	d, err := s.groups.Create(ctx, f.organizer, service.NewGroup{
		Name: "Arisan RT 05", Amount: 150_000, PeriodType: model.PeriodTypeMonthly, TotalSlots: 3,
		DrawMethod: model.DrawMethodRandom, StartDate: utils.Today(time.Now(), jakarta).AddDate(0, 0, 7), ReminderDaysBefore: 2,
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	gid := d.Group.ID
	member, err := s.members.Join(ctx, f.member, d.Invite.Code)
	if err != nil {
		t.Fatalf("Join: %v", err)
	}
	guest, err := s.members.AddGuest(ctx, gid, f.organizer, "Tamu Satu", nil)
	if err != nil {
		t.Fatalf("AddGuest: %v", err)
	}
	if _, err := s.groups.SetPaymentInfo(ctx, gid, f.organizer, "BCA", "1234567890", "Rina Susanti"); err != nil {
		t.Fatalf("SetPaymentInfo: %v", err)
	}
	started, err := s.groups.Start(ctx, gid, f.organizer)
	if err != nil {
		t.Fatalf("Start: %v", err)
	}
	board, _, err := s.pays.Board(ctx, gid, *started.CurrentPeriodID, f.organizer)
	if err != nil {
		t.Fatalf("Board: %v", err)
	}
	var memberPayment uuid.UUID
	for _, p := range board {
		if p.Payment.MemberID == member.Member.ID {
			memberPayment = p.Payment.ID
		}
	}
	leave, err := s.leaves.Request(ctx, gid, f.member, nil)
	if err != nil {
		t.Fatalf("Request leave: %v", err)
	}
	offer, err := s.owners.Offer(ctx, gid, f.organizer, member.Member.ID)
	if err != nil {
		t.Fatalf("Offer: %v", err)
	}
	f.params = map[string]string{
		":group_id":    gid.String(),
		":member_id":   guest.Member.ID.String(),
		":request_id":  leave.Request.ID.String(),
		":transfer_id": offer.Transfer.ID.String(),
		":period_id":   started.CurrentPeriodID.String(),
		":payment_id":  memberPayment.String(),
		"$to_member":   member.Member.ID.String(),
	}
	return f
}

// sweepBody builds a request body and its content type.
type sweepBody func(t *testing.T, f sweepFixture) (io.Reader, string)

func jsonBody(raw string) sweepBody {
	return func(_ *testing.T, f sweepFixture) (io.Reader, string) {
		return strings.NewReader(strings.ReplaceAll(raw, "$to_member", f.params["$to_member"])), fiber.MIMEApplicationJSON
	}
}

// formBody is a multipart form with a PNG in "file" when withFile is set,
// plus the given text fields.
func formBody(withFile bool, fields map[string]string) sweepBody {
	return func(t *testing.T, _ sweepFixture) (io.Reader, string) {
		t.Helper()
		var buf bytes.Buffer
		w := multipart.NewWriter(&buf)
		if withFile {
			part, err := w.CreateFormFile("file", "image.png")
			if err != nil {
				t.Fatalf("CreateFormFile: %v", err)
			}
			img := image.NewNRGBA(image.Rect(0, 0, 16, 16))
			for i := range img.Pix {
				img.Pix[i] = 0xff
			}
			img.Set(3, 3, color.Black)
			if err := png.Encode(part, img); err != nil {
				t.Fatalf("png: %v", err)
			}
		}
		for k, v := range fields {
			if err := w.WriteField(k, v); err != nil {
				t.Fatalf("WriteField: %v", err)
			}
		}
		if err := w.Close(); err != nil {
			t.Fatalf("multipart close: %v", err)
		}
		return &buf, w.FormDataContentType()
	}
}

const (
	memberAllowed   = "" // neither group_not_found nor forbidden_role
	memberForbidden = "forbidden_role"
)

// groupRoutes is every route under /groups/{group_id} with a valid body and
// what a plain member gets (PRD §5). The body matters: an invalid one would
// be answered by the controller's 422 before the service checks the role.
// The member pass runs in this order, so the ownership responses come last
// and the organizer never changes.
var groupRoutes = []struct {
	method, path string
	body         sweepBody
	member       string
}{
	{http.MethodGet, "", nil, memberAllowed},
	{http.MethodPatch, "", jsonBody(`{"name":"Arisan Baru"}`), memberForbidden},
	{http.MethodPut, "/payment-info", jsonBody(`{"bank_name":"BRI","account_number":"9876543210","account_holder":"Budi"}`), memberForbidden},
	{http.MethodPut, "/payment-info/qris", formBody(true, nil), memberForbidden},
	{http.MethodDelete, "/payment-info/qris", nil, memberForbidden},
	{http.MethodPut, "/fixed-order", jsonBody(`{"order":[{"slot_id":"0192c3a4-0000-7000-8000-000000000001","position":1},{"slot_id":"0192c3a4-0000-7000-8000-000000000002","position":2}]}`), memberForbidden},
	{http.MethodPost, "/start", nil, memberForbidden},
	{http.MethodPost, "/close", nil, memberForbidden},
	{http.MethodPost, "/invite-code/reset", nil, memberForbidden},
	{http.MethodGet, "/members", nil, memberAllowed},
	{http.MethodPost, "/guests", jsonBody(`{"name":"Tamu Dua"}`), memberForbidden},
	{http.MethodGet, "/members/:member_id", nil, memberAllowed},
	{http.MethodPatch, "/members/:member_id", jsonBody(`{"name":"Tamu Baru"}`), memberForbidden},
	{http.MethodDelete, "/members/:member_id", nil, memberForbidden},
	{http.MethodPost, "/members/:member_id/claim-link", nil, memberForbidden},
	{http.MethodGet, "/leave-requests", nil, memberAllowed},
	{http.MethodPost, "/leave-requests", jsonBody(`{}`), memberAllowed},
	{http.MethodPost, "/leave-requests/:request_id/approve", nil, memberForbidden},
	{http.MethodPost, "/leave-requests/:request_id/reject", jsonBody(`{}`), memberForbidden},
	{http.MethodPost, "/ownership-transfers", jsonBody(`{"to_member_id":"$to_member"}`), memberForbidden},
	{http.MethodGet, "/periods", nil, memberAllowed},
	{http.MethodGet, "/periods/:period_id", nil, memberAllowed},
	{http.MethodGet, "/periods/:period_id/payments", nil, memberAllowed},
	{http.MethodGet, "/payments/:payment_id", nil, memberAllowed},
	{http.MethodPost, "/payments/:payment_id/proofs", formBody(true, nil), memberAllowed},
	{http.MethodPost, "/payments/:payment_id/approve", nil, memberForbidden},
	{http.MethodPost, "/payments/:payment_id/reject", jsonBody(`{"reason":"Bukti buram"}`), memberForbidden},
	{http.MethodPost, "/payments/:payment_id/mark-paid", jsonBody(`{"method":"cash"}`), memberForbidden},
	{http.MethodGet, "/periods/:period_id/draw", nil, memberAllowed},
	{http.MethodPost, "/periods/:period_id/draw", jsonBody(`{}`), memberForbidden},
	{http.MethodGet, "/periods/:period_id/payout", nil, memberAllowed},
	{http.MethodPost, "/periods/:period_id/payout", formBody(false, map[string]string{"note": "Tunai"}), memberForbidden},
	{http.MethodPost, "/periods/:period_id/payout/confirm", nil, memberAllowed},
	{http.MethodPost, "/periods/:period_id/reminders", jsonBody(`{}`), memberForbidden},
	{http.MethodGet, "/periods/:period_id/recap", nil, memberAllowed},
	{http.MethodGet, "/activity", nil, memberAllowed},
	{http.MethodGet, "/obligations", nil, memberAllowed},
	{http.MethodPost, "/ownership-transfers/:transfer_id/decline", nil, memberAllowed},
	{http.MethodPost, "/ownership-transfers/:transfer_id/accept", nil, memberAllowed},
}

const groupPrefix = "/api/v1/groups/:group_id"

// leakMarkers must never appear in a response body.
var leakMarkers = []string{"SQLSTATE", "pgx", "pq:", "violates", "syntax error", "goroutine", ".go:"}

// sweepCall sends one table route as userID, with params filled in from f
// (groupID overrides the group), and returns the status, code and raw body.
func sweepCall(t *testing.T, s sweepApp, f sweepFixture, userID uuid.UUID, groupID, method, path string, body sweepBody) (int, string, []byte) {
	t.Helper()
	url := groupPrefix + path
	for k, v := range f.params {
		if k == ":group_id" && groupID != "" {
			v = groupID
		}
		url = strings.ReplaceAll(url, k, v)
	}
	var r io.Reader
	contentType := ""
	if body != nil {
		r, contentType = body(t, f)
	}
	req := httptest.NewRequest(method, url, r)
	if contentType != "" {
		req.Header.Set(fiber.HeaderContentType, contentType)
	}
	token, _, err := s.tokens.Issue(userID, uuid.Must(uuid.NewV7()))
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
	req.Header.Set(controller.HeaderIdempotencyKey, uuid.Must(uuid.NewV7()).String())
	resp, err := s.app.Test(req, fiber.TestConfig{Timeout: 10 * time.Second})
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	for _, m := range leakMarkers {
		if bytes.Contains(raw, []byte(m)) {
			t.Errorf("%s %s: body leaks %q: %s", method, url, m, raw)
		}
	}
	var problem struct {
		Code string `json:"code"`
	}
	_ = json.Unmarshal(raw, &problem) // success bodies have no code
	return resp.StatusCode, problem.Code, raw
}

func TestGroupRoutesTableCoversEveryRoute(t *testing.T) {
	// Arrange
	s := newSweepApp(t)
	listed := map[string]bool{}
	for _, r := range groupRoutes {
		listed[r.method+" "+groupPrefix+r.path] = true
	}

	// Act
	registered := map[string]bool{}
	for _, r := range s.app.GetRoutes(true) {
		if r.Method != http.MethodHead && strings.HasPrefix(r.Path, groupPrefix) {
			registered[r.Method+" "+r.Path] = true
		}
	}

	// Assert
	for r := range registered {
		if !listed[r] {
			t.Errorf("%s has no authorization case in groupRoutes", r)
		}
	}
	for r := range listed {
		if !registered[r] {
			t.Errorf("groupRoutes lists %s, which is not registered", r)
		}
	}
}

func TestGroupRoutesAuthorization(t *testing.T) {
	// Arrange
	s := newSweepApp(t)
	f := newSweepFixture(t, s)

	// Subtests share the fixture, so they run in order and never in parallel.
	t.Run("non-member", func(t *testing.T) {
		for _, r := range groupRoutes {
			t.Run(r.method+" "+r.path, func(t *testing.T) {
				// Act
				status, code, raw := sweepCall(t, s, f, f.outsider, "", r.method, r.path, r.body)

				// Assert
				if status != fiber.StatusNotFound || code != "group_not_found" {
					t.Errorf("status %d code %q, want 404 group_not_found; body %s", status, code, raw)
				}
			})
		}
	})

	t.Run("unknown group", func(t *testing.T) {
		unknown := uuid.Must(uuid.NewV7()).String()
		for _, r := range groupRoutes {
			t.Run(r.method+" "+r.path, func(t *testing.T) {
				// Act
				status, code, raw := sweepCall(t, s, f, f.organizer, unknown, r.method, r.path, r.body)

				// Assert
				if status != fiber.StatusNotFound || code != "group_not_found" {
					t.Errorf("status %d code %q, want 404 group_not_found; body %s", status, code, raw)
				}
			})
		}
	})

	t.Run("member", func(t *testing.T) {
		for _, r := range groupRoutes {
			t.Run(r.method+" "+r.path, func(t *testing.T) {
				// Act
				status, code, raw := sweepCall(t, s, f, f.member, "", r.method, r.path, r.body)

				// Assert
				if status >= 500 {
					t.Errorf("status %d; body %s", status, raw)
				}
				switch r.member {
				case memberForbidden:
					if status != fiber.StatusForbidden || code != "forbidden_role" {
						t.Errorf("status %d code %q, want 403 forbidden_role; body %s", status, code, raw)
					}
				default:
					if code == "group_not_found" || code == "forbidden_role" {
						t.Errorf("status %d code %q, want the member let through; body %s", status, code, raw)
					}
				}
			})
		}
	})
}
