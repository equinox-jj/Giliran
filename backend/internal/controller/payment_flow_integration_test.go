//go:build integration

package controller

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/png"
	"io"
	"log/slog"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
	"github.com/equinox-jj/Giliran/backend/test/integration"
)

// flowStore keeps uploaded objects in memory.
type flowStore struct {
	mu      sync.Mutex
	objects map[string][]byte
}

func (s *flowStore) Put(_ context.Context, key, _ string, r io.Reader, _ int64) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.objects[key] = data
	return nil
}

func (s *flowStore) Delete(_ context.Context, key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.objects, key)
	return nil
}

func (s *flowStore) PresignGet(_ context.Context, key string) (string, error) {
	return "https://files.test/" + key, nil
}

// paymentFlow is a started two-slot group served over HTTP with the real
// services, the real Idempotency middleware and Postgres.
type paymentFlow struct {
	app       *fiber.App
	pool      *pgxpool.Pool
	clock     *clock.Fake
	groupID   uuid.UUID
	rina      uuid.UUID
	budi      uuid.UUID
	budiPayID uuid.UUID
}

func newPaymentFlow(t *testing.T) paymentFlow {
	t.Helper()
	ctx := context.Background()
	pool := integration.NewDB(t)
	tx := repository.NewTxManager(pool)
	clk := clock.NewFake(time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC))
	jakarta, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		t.Fatalf("LoadLocation: %v", err)
	}
	cfg := &config.Config{
		App:   config.App{PublicBaseURL: "https://giliran.test", Location: jakarta},
		MinIO: config.MinIO{UploadMaxBytes: 5 << 20},
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	store := &flowStore{objects: map[string][]byte{}}
	users := repository.NewUserRepository(tx)
	groups := repository.NewGroupRepository(tx)
	members := repository.NewMemberRepository(tx)
	leaves := repository.NewLeaveRequestRepository(tx)
	transfers := repository.NewOwnershipTransferRepository(tx)
	periods := repository.NewPeriodRepository(tx)
	payments := repository.NewPaymentRepository(tx)
	authz := service.NewAuthz(groups, members)
	activity := service.NewActivity(repository.NewActivityRepository(tx), clk)
	groupSvc := service.NewGroupService(tx, groups, members, leaves, transfers, periods, payments, users, authz, activity, store, clk, log, cfg)
	memberSvc := service.NewMemberService(tx, groups, members, leaves, transfers, users, authz, activity, store, clk, cfg)
	enqueuer, err := jobs.NewEnqueuer(pool, log)
	if err != nil {
		t.Fatalf("NewEnqueuer: %v", err)
	}
	paymentSvc := service.NewPaymentService(tx, groups, periods, payments, members, users, authz, activity, enqueuer, store, clk, log, cfg)
	logs := repository.NewActivityRepository(tx)
	drawSvc := service.NewDrawService(tx, groups, periods, payments, members, logs, users, authz, activity, enqueuer, store, clk, cfg)
	payoutSvc := service.NewPayoutService(tx, groups, periods, payments, repository.NewPayoutRepository(tx), members, users, authz, activity, enqueuer, store, clk, log, cfg)
	idem := service.NewIdempotencyService(tx, repository.NewIdempotencyRepository(tx), clk)

	f := paymentFlow{pool: pool, clock: clk, rina: uuid.Must(uuid.NewV7()), budi: uuid.Must(uuid.NewV7())}
	for id, email := range map[uuid.UUID]string{f.rina: "rina@example.com", f.budi: "budi@example.com"} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id, email, email_verified_at, name) VALUES ($1, $2, now(), 'Anggota')`, id, email); err != nil {
			t.Fatalf("insert user: %v", err)
		}
	}
	d, err := groupSvc.Create(ctx, f.rina, service.NewGroup{
		Name: "Arisan RT 05", Amount: 150_000, PeriodType: model.PeriodTypeMonthly, TotalSlots: 2,
		DrawMethod: model.DrawMethodRandom, StartDate: utils.Date(2026, time.November, 1), ReminderDaysBefore: 2,
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	f.groupID = d.Group.ID
	budi, err := memberSvc.Join(ctx, f.budi, d.Invite.Code)
	if err != nil {
		t.Fatalf("Join: %v", err)
	}
	if _, err := groupSvc.SetPaymentInfo(ctx, f.groupID, f.rina, "BCA", "1234567890", "Rina Susanti"); err != nil {
		t.Fatalf("SetPaymentInfo: %v", err)
	}
	started, err := groupSvc.Start(ctx, f.groupID, f.rina)
	if err != nil {
		t.Fatalf("Start: %v", err)
	}
	board, _, err := paymentSvc.Board(ctx, f.groupID, *started.CurrentPeriodID, f.rina)
	if err != nil {
		t.Fatalf("Board: %v", err)
	}
	for _, p := range board {
		if p.Payment.MemberID == budi.Member.ID {
			f.budiPayID = p.Payment.ID
		}
	}

	f.app = fiber.New(fiber.Config{ErrorHandler: response.ErrorHandler(log), StructValidator: validation.New()})
	f.app.Use(middleware.RequestID())
	h := &PaymentController{payments: paymentSvc}
	guard := (&Idempotency{runner: idem}).Handle
	g := f.app.Group("/api/v1/groups/:group_id", middleware.Auth(testTokens))
	g.Post("/payments/:payment_id/proofs", guard, h.UploadProof)
	g.Post("/payments/:payment_id/approve", guard, h.Approve)
	g.Post("/payments/:payment_id/reject", guard, h.Reject)
	g.Post("/payments/:payment_id/mark-paid", guard, h.MarkPaid)
	draws := &DrawController{draws: drawSvc}
	payouts := &PayoutController{payouts: payoutSvc}
	g.Get("/periods/:period_id/draw", draws.Get)
	g.Post("/periods/:period_id/draw", guard, draws.Run)
	g.Get("/periods/:period_id/payout", payouts.Get)
	g.Post("/periods/:period_id/payout", guard, payouts.Record)
	g.Post("/periods/:period_id/payout/confirm", guard, payouts.Confirm)
	f.app.Get("/api/v1/public/draws/:verification_code", draws.Public)
	f.app.Get("/v/:verification_code", draws.Page)
	return f
}

func (f paymentFlow) path(action string) string {
	return "/api/v1/groups/" + f.groupID.String() + "/payments/" + f.budiPayID.String() + "/" + action
}

// as signs req in as userID with an Idempotency-Key.
func (f paymentFlow) as(t *testing.T, req *http.Request, userID uuid.UUID, key string) *http.Request {
	t.Helper()
	token, _, err := testTokens.Issue(userID, uuid.Must(uuid.NewV7()))
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
	req.Header.Set(HeaderIdempotencyKey, key)
	return req
}

func (f paymentFlow) send(t *testing.T, req *http.Request) (*http.Response, map[string]any) {
	t.Helper()
	return call(t, f.app, req)
}

func (f paymentFlow) count(t *testing.T, action string) int {
	t.Helper()
	var n int
	if err := f.pool.QueryRow(context.Background(), `SELECT count(*) FROM activity_logs WHERE action = $1`, action).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	return n
}

func flowPNG(t *testing.T) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, 16, 16))
	img.Set(1, 1, color.Black)
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}

// uploaded has Budi's proof uploaded over HTTP with key.
func (f paymentFlow) uploaded(t *testing.T, key string) {
	t.Helper()
	req := f.as(t, proofRequest(t, f.path("proofs"), "boundary-one", flowPNG(t)), f.budi, key)
	if resp, body := f.send(t, req); resp.StatusCode != 201 {
		t.Fatalf("upload: %d %v", resp.StatusCode, body)
	}
}

func TestPaymentFlowUploadRetryReplays(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)
	f.uploaded(t, "upload-key-0001")
	retry := f.as(t, proofRequest(t, f.path("proofs"), "boundary-two", flowPNG(t)), f.budi, "upload-key-0001")

	// Act
	resp, body := f.send(t, retry)

	// Assert
	if resp.StatusCode != 201 || resp.Header.Get(HeaderIdempotentReplayed) != "true" || body["data"].(map[string]any)["status"] != "pending_review" {
		t.Fatalf("retry: %d, replayed %q, body %v", resp.StatusCode, resp.Header.Get(HeaderIdempotentReplayed), body)
	}
	if n := f.count(t, "payment.proof_uploaded"); n != 1 {
		t.Errorf("%d uploads logged, want 1", n)
	}
}

func TestPaymentFlowApproveTwiceWithOneKey(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)
	f.uploaded(t, "upload-key-0001")
	first, _ := f.send(t, f.as(t, jsonRequest(f.path("approve"), ""), f.rina, "approve-key-0001"))
	if first.StatusCode != 200 {
		t.Fatalf("first approve: %d", first.StatusCode)
	}

	// Act
	resp, body := f.send(t, f.as(t, jsonRequest(f.path("approve"), ""), f.rina, "approve-key-0001"))

	// Assert
	if resp.StatusCode != 200 || resp.Header.Get(HeaderIdempotentReplayed) != "true" || body["data"].(map[string]any)["status"] != "paid" {
		t.Fatalf("second approve: %d, replayed %q, body %v", resp.StatusCode, resp.Header.Get(HeaderIdempotentReplayed), body)
	}
	if n := f.count(t, "payment.approved"); n != 1 {
		t.Errorf("%d approvals logged, want 1", n)
	}
}

func TestPaymentFlowKeyReusedOnAnotherRoute(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)
	f.uploaded(t, "upload-key-0001")
	if resp, _ := f.send(t, f.as(t, jsonRequest(f.path("approve"), ""), f.rina, "shared-key-0001")); resp.StatusCode != 200 {
		t.Fatalf("approve: %d", resp.StatusCode)
	}

	// Act
	resp, body := f.send(t, f.as(t, jsonRequest(f.path("reject"), `{"reason":"Buram sekali"}`), f.rina, "shared-key-0001"))

	// Assert
	if resp.StatusCode != 422 || body["code"] != "idempotency_key_reused" {
		t.Errorf("status %d, code %v", resp.StatusCode, body["code"])
	}
}

func TestPaymentFlowFailedWriteLeavesNoKey(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)

	// Act
	resp, body := f.send(t, f.as(t, jsonRequest(f.path("approve"), ""), f.rina, "approve-key-0001"))

	// Assert
	if resp.StatusCode != 409 || body["code"] != "invalid_payment_state" {
		t.Fatalf("approve unpaid: %d %v", resp.StatusCode, body)
	}
	var n int
	if err := f.pool.QueryRow(context.Background(), `SELECT count(*) FROM idempotency_keys`).Scan(&n); err != nil || n != 0 {
		t.Errorf("%d stored keys (%v), want none", n, err)
	}
}
