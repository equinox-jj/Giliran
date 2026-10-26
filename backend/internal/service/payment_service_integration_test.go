//go:build integration

package service

import (
	"context"
	"encoding/json"
	"errors"
	"image/color"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/images"
)

// upload uploads a proof as userID and fails the test on error.
func (e paymentEnv) upload(t *testing.T, a arisan, paymentID, userID uuid.UUID, c color.Color) PaymentView {
	t.Helper()
	v, err := e.payments.UploadProof(context.Background(), a.groupID, paymentID, userID, testPNG(t, c))
	if err != nil {
		t.Fatalf("UploadProof: %v", err)
	}
	return v
}

func TestPaymentUploadProofPutsPaymentInReview(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)

	// Act
	v, err := env.payments.UploadProof(context.Background(), a.groupID, pay["budi"], a.budi, testPNG(t, color.White))

	// Assert
	if err != nil || v.Payment.Status != model.PaymentStatusPendingReview || !v.IsMine || v.CurrentProof == nil {
		t.Fatalf("UploadProof: %v, view %+v", err, v)
	}
	if v.CurrentProof.ContentType != model.ProofContentTypeJPEG || !strings.HasPrefix(v.CurrentProof.URL, "https://files.test/proofs/") {
		t.Errorf("proof %+v", v.CurrentProof)
	}
	keys := env.store.keys()
	if len(keys) != 1 {
		t.Fatalf("stored %v", keys)
	}
	if ct, _ := images.Sniff(env.store.objects[keys[0]]); ct != images.JPEG {
		t.Errorf("stored %s, want a re-encoded JPEG", ct)
	}
	if acts := env.actions(t, a.groupID); acts[len(acts)-1] != "payment.proof_uploaded" {
		t.Errorf("activity %v", acts)
	}
}

func TestPaymentUploadProofReplacesPendingProof(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	first := env.upload(t, a, pay["budi"], a.budi, color.White)

	// Act
	second, err := env.payments.UploadProof(context.Background(), a.groupID, pay["budi"], a.budi, testPNG(t, color.Black))

	// Assert
	if err != nil || second.CurrentProof == nil || second.CurrentProof.ID == first.CurrentProof.ID {
		t.Fatalf("UploadProof: %v, proof %+v", err, second.CurrentProof)
	}
	d, err := env.payments.Get(context.Background(), a.groupID, pay["budi"], a.budi)
	if err != nil || len(d.Proofs) != 2 || d.Proofs[0].ID != second.CurrentProof.ID {
		t.Fatalf("Get: %v, proofs %+v", err, d.Proofs)
	}
}

func TestPaymentUploadProofRefuses(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		setup func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (paymentID, userID uuid.UUID, data []byte)
		want  error
	}{
		{"another member's payment", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			return pay["budi"], a.sari, testPNG(t, color.White)
		}, model.ErrForbiddenRole},
		{"organizer on a guest's payment", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			return pay["darto"], a.rina, testPNG(t, color.White)
		}, model.ErrForbiddenRole},
		{"paid payment", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			if _, err := env.payments.MarkPaid(context.Background(), a.groupID, pay["budi"], a.rina, model.PaymentMethodCash, nil); err != nil {
				t.Fatalf("MarkPaid: %v", err)
			}
			return pay["budi"], a.budi, testPNG(t, color.White)
		}, model.ErrInvalidPaymentState},
		{"not an image", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			return pay["budi"], a.budi, []byte("%PDF-1.7 not an image")
		}, model.ErrUnsupportedMediaType},
		{"too large", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			return pay["budi"], a.budi, make([]byte, 5<<20+1)
		}, model.ErrFileTooLarge},
		{"unknown payment", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			return uuid.Must(uuid.NewV7()), a.budi, testPNG(t, color.White)
		}, model.ErrPaymentNotFound},
		{"closed group", func(t *testing.T, env paymentEnv, a arisan, pay map[string]uuid.UUID) (uuid.UUID, uuid.UUID, []byte) {
			if _, err := env.groups.Close(context.Background(), a.groupID, a.rina); err != nil {
				t.Fatalf("Close: %v", err)
			}
			return pay["budi"], a.budi, testPNG(t, color.White)
		}, model.ErrGroupNotActive},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			env := newPaymentEnv(t)
			a, _, pay := env.started(t)
			paymentID, userID, data := tt.setup(t, env, a, pay)

			// Act
			_, err := env.payments.UploadProof(context.Background(), a.groupID, paymentID, userID, data)

			// Assert
			wantErr(t, err, tt.want)
			if keys := env.store.keys(); len(keys) != 0 {
				t.Errorf("objects left behind: %v", keys)
			}
		})
	}
}

func TestPaymentProofsVisibleToPayerAndOrganizersOnly(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	tests := []struct {
		name    string
		userID  uuid.UUID
		visible bool
	}{
		{"payer", a.budi, true},
		{"organizer", a.rina, true},
		{"other member", a.sari, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			d, err := env.payments.Get(context.Background(), a.groupID, pay["budi"], tt.userID)

			// Assert
			if err != nil {
				t.Fatalf("Get: %v", err)
			}
			if got := d.CurrentProof != nil && len(d.Proofs) == 1; got != tt.visible {
				t.Errorf("proof visible %v, want %v (current %+v, %d proofs)", got, tt.visible, d.CurrentProof, len(d.Proofs))
			}
			if d.Proofs == nil {
				t.Error("proofs is nil, want an empty list")
			}
		})
	}
}

func TestPaymentApprove(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)

	// Act
	v, err := env.payments.Approve(context.Background(), a.groupID, pay["budi"], a.rina)

	// Assert
	p := v.Payment
	if err != nil || p.Status != model.PaymentStatusPaid || p.PaidAt == nil || p.ReviewedAt == nil ||
		*p.Method != model.PaymentMethodTransfer || v.ReviewedBy == nil || v.ReviewedBy.ID != a.rina {
		t.Fatalf("Approve: %v, payment %+v, reviewer %+v", err, p, v.ReviewedBy)
	}
	if _, after := env.lastLog(t, a.groupID); after != `{"status": "paid"}` {
		t.Errorf("logged %s", after)
	}
}

func TestPaymentRejectThenReupload(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	rejected, err := env.payments.Reject(context.Background(), a.groupID, pay["budi"], a.rina, "  Nominal kurang Rp50.000.  ")
	if err != nil || rejected.Payment.Status != model.PaymentStatusRejected || *rejected.Payment.RejectReason != "Nominal kurang Rp50.000." {
		t.Fatalf("Reject: %v, payment %+v", err, rejected.Payment)
	}

	// Act
	v, err := env.payments.UploadProof(context.Background(), a.groupID, pay["budi"], a.budi, testPNG(t, color.Black))

	// Assert
	if err != nil || v.Payment.Status != model.PaymentStatusPendingReview || v.Payment.RejectReason != nil || v.ReviewedBy != nil {
		t.Fatalf("UploadProof: %v, payment %+v", err, v.Payment)
	}
}

func TestPaymentMarkPaid(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	note := " Bayar tunai di rumah. "

	// Act
	v, err := env.payments.MarkPaid(context.Background(), a.groupID, pay["darto"], a.rina, model.PaymentMethodCash, &note)

	// Assert
	p := v.Payment
	if err != nil || p.Status != model.PaymentStatusPaid || *p.Method != model.PaymentMethodCash || *p.Note != "Bayar tunai di rumah." {
		t.Fatalf("MarkPaid: %v, payment %+v", err, p)
	}
	if acts := env.actions(t, a.groupID); acts[len(acts)-1] != "payment.marked_paid" {
		t.Errorf("activity %v", acts)
	}
}

func TestPaymentReviewRefuses(t *testing.T) {
	// Arrange
	type act func(env paymentEnv, a arisan, paymentID uuid.UUID) error
	approve := func(userID func(arisan) uuid.UUID) act {
		return func(env paymentEnv, a arisan, id uuid.UUID) error {
			_, err := env.payments.Approve(context.Background(), a.groupID, id, userID(a))
			return err
		}
	}
	byRina := func(a arisan) uuid.UUID { return a.rina }
	reject := func(reason string) act {
		return func(env paymentEnv, a arisan, id uuid.UUID) error {
			_, err := env.payments.Reject(context.Background(), a.groupID, id, a.rina, reason)
			return err
		}
	}
	markPaid := func(env paymentEnv, a arisan, id uuid.UUID) error {
		_, err := env.payments.MarkPaid(context.Background(), a.groupID, id, a.rina, model.PaymentMethodCash, nil)
		return err
	}
	tests := []struct {
		name  string
		setup func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID)
		act   act
		want  error
	}{
		{"approve unpaid", nil, approve(byRina), model.ErrInvalidPaymentState},
		{"approve twice", func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID) {
			env.upload(t, a, id, a.budi, color.White)
			if _, err := env.payments.Approve(context.Background(), a.groupID, id, a.rina); err != nil {
				t.Fatalf("Approve: %v", err)
			}
		}, approve(byRina), model.ErrPaymentAlreadyReviewed},
		{"approve rejected", func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID) {
			env.upload(t, a, id, a.budi, color.White)
			if _, err := env.payments.Reject(context.Background(), a.groupID, id, a.rina, "Buram"); err != nil {
				t.Fatalf("Reject: %v", err)
			}
		}, approve(byRina), model.ErrPaymentAlreadyReviewed},
		{"approve by member", func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID) {
			env.upload(t, a, id, a.budi, color.White)
		}, approve(func(a arisan) uuid.UUID { return a.sari }), model.ErrForbiddenRole},
		{"reject unpaid", nil, reject("Buram"), model.ErrInvalidPaymentState},
		{"reject with short reason", func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID) {
			env.upload(t, a, id, a.budi, color.White)
		}, reject("  x "), model.ErrValidation},
		{"mark pending paid", func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID) {
			env.upload(t, a, id, a.budi, color.White)
		}, markPaid, model.ErrInvalidPaymentState},
		{"mark paid twice", func(t *testing.T, env paymentEnv, a arisan, id uuid.UUID) {
			if err := markPaid(env, a, id); err != nil {
				t.Fatalf("MarkPaid: %v", err)
			}
		}, markPaid, model.ErrInvalidPaymentState},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			env := newPaymentEnv(t)
			a, _, pay := env.started(t)
			if tt.setup != nil {
				tt.setup(t, env, a, pay["budi"])
			}

			// Act
			err := tt.act(env, a, pay["budi"])

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestPaymentMarkPaidRejected(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	if _, err := env.payments.Reject(context.Background(), a.groupID, pay["budi"], a.rina, "Buram"); err != nil {
		t.Fatalf("Reject: %v", err)
	}

	// Act
	v, err := env.payments.MarkPaid(context.Background(), a.groupID, pay["budi"], a.rina, model.PaymentMethodTransfer, nil)

	// Assert
	if err != nil || v.Payment.Status != model.PaymentStatusPaid || v.Payment.RejectReason != nil {
		t.Fatalf("MarkPaid: %v, payment %+v", err, v.Payment)
	}
}

func TestPaymentBoardSummary(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, period, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	if _, err := env.payments.Approve(context.Background(), a.groupID, pay["budi"], a.rina); err != nil {
		t.Fatalf("Approve: %v", err)
	}
	if _, err := env.payments.MarkPaid(context.Background(), a.groupID, pay["darto"], a.rina, model.PaymentMethodCash, nil); err != nil {
		t.Fatalf("MarkPaid: %v", err)
	}
	env.upload(t, a, pay["sari"], a.sari, color.White)

	// Act
	board, sum, err := env.payments.Board(context.Background(), a.groupID, period.ID, a.sari)

	// Assert
	if err != nil || len(board) != 4 {
		t.Fatalf("Board: %v, %d payments", err, len(board))
	}
	want := struct{ paid, pending, unpaid int }{2, 1, 1}
	if sum.PaidCount != want.paid || sum.PendingReviewCount != want.pending || sum.UnpaidCount != want.unpaid ||
		sum.CollectedAmount != 300_000 || sum.ExpectedAmount != 600_000 {
		t.Errorf("summary %+v", sum)
	}
	for i, v := range board {
		if v.Member.SlotNo != int16(i+1) {
			t.Errorf("payment %d is slot %d", i, v.Member.SlotNo)
		}
		if mine := v.Payment.MemberID == a.memberIDs["sari"]; v.IsMine != mine || (v.CurrentProof != nil) != (mine && v.Payment.HasProof()) {
			t.Errorf("payment of %s: mine %v, proof %+v", v.Member.DisplayName(), v.IsMine, v.CurrentProof)
		}
	}
}

func TestPaymentBoardUnknownPeriod(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, _ := env.started(t)

	// Act
	_, _, err := env.payments.Board(context.Background(), a.groupID, uuid.Must(uuid.NewV7()), a.budi)

	// Assert
	wantErr(t, err, model.ErrPeriodNotFound)
}

// approveOnce approves paymentID through the idempotency key, the way the
// middleware does.
func (e paymentEnv) approveOnce(ctx context.Context, a arisan, paymentID uuid.UUID, key, hash string) (StoredResponse, bool, error) {
	req := IdempotentRequest{UserID: a.rina, Key: key, Method: "POST", Path: "/approve/" + paymentID.String(), Hash: hash}
	return e.idem.Run(ctx, req, func(ctx context.Context) (StoredResponse, error) {
		v, err := e.payments.Approve(ctx, a.groupID, paymentID, a.rina)
		if err != nil {
			return StoredResponse{}, err
		}
		body, err := json.Marshal(map[string]any{"status": v.Payment.Status})
		return StoredResponse{Status: 200, Body: body}, err
	})
}

func TestIdempotencyReplaysCompletedRequest(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	first, _, err := env.approveOnce(context.Background(), a, pay["budi"], "key-approve-1", "h1")
	if err != nil {
		t.Fatalf("first approve: %v", err)
	}

	// Act
	again, replayed, err := env.approveOnce(context.Background(), a, pay["budi"], "key-approve-1", "h1")

	// Assert
	// jsonb normalizes spacing and key order, so compare values.
	if err != nil || !replayed || again.Status != first.Status || !sameJSON(t, again.Body, first.Body) {
		t.Fatalf("replay: %v, replayed %v, %d %s", err, replayed, again.Status, again.Body)
	}
	if n := env.count(t, `SELECT count(*) FROM activity_logs WHERE action = 'payment.approved'`); n != 1 {
		t.Errorf("%d approvals logged, want 1", n)
	}
}

func sameJSON(t *testing.T, a, b []byte) bool {
	t.Helper()
	var va, vb any
	if err := json.Unmarshal(a, &va); err != nil {
		t.Fatalf("unmarshal %s: %v", a, err)
	}
	if err := json.Unmarshal(b, &vb); err != nil {
		t.Fatalf("unmarshal %s: %v", b, err)
	}
	return reflect.DeepEqual(va, vb)
}

func TestIdempotencyRejectsReusedKey(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	if _, _, err := env.approveOnce(context.Background(), a, pay["budi"], "key-approve-1", "h1"); err != nil {
		t.Fatalf("first approve: %v", err)
	}

	// Act
	_, _, err := env.approveOnce(context.Background(), a, pay["budi"], "key-approve-1", "h2")

	// Assert
	wantErr(t, err, model.ErrIdempotencyKeyReused)
}

func TestIdempotencyFailureIsNotStored(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	if _, _, err := env.approveOnce(context.Background(), a, pay["budi"], "key-approve-1", "h1"); !errors.Is(err, model.ErrInvalidPaymentState) {
		t.Fatalf("approve unpaid: %v", err)
	}
	env.upload(t, a, pay["budi"], a.budi, color.White)

	// Act
	_, replayed, err := env.approveOnce(context.Background(), a, pay["budi"], "key-approve-1", "h1")

	// Assert
	if err != nil || replayed {
		t.Fatalf("retry: %v, replayed %v", err, replayed)
	}
}

// concurrentApprovals approves Budi's pending payment from two goroutines
// with the given keys and returns their results.
func concurrentApprovals(t *testing.T, keys [2]string) (paymentEnv, [2]error, [2]bool) {
	t.Helper()
	env := newPaymentEnv(t)
	a, _, pay := env.started(t)
	env.upload(t, a, pay["budi"], a.budi, color.White)
	var errs [2]error
	var replayed [2]bool
	var wg sync.WaitGroup
	for i := range 2 {
		wg.Go(func() {
			_, replayed[i], errs[i] = env.approveOnce(context.Background(), a, pay["budi"], keys[i], "h1")
		})
	}
	wg.Wait()
	return env, errs, replayed
}

func TestIdempotencyConcurrentSameKeyWritesOnce(t *testing.T) {
	t.Parallel()

	// Act
	env, errs, replayed := concurrentApprovals(t, [2]string{"key-approve-1", "key-approve-1"})

	// Assert
	if errs[0] != nil || errs[1] != nil || replayed[0] == replayed[1] {
		t.Fatalf("errs %v, replayed %v; want both to succeed, one replayed", errs, replayed)
	}
	if n := env.count(t, `SELECT count(*) FROM activity_logs WHERE action = 'payment.approved'`); n != 1 {
		t.Errorf("%d approvals logged, want 1", n)
	}
}

func TestIdempotencyConcurrentDifferentKeysApproveOnce(t *testing.T) {
	t.Parallel()

	// Act
	env, errs, _ := concurrentApprovals(t, [2]string{"key-device-a", "key-device-b"})

	// Assert
	ok, already := 0, 0
	for _, err := range errs {
		switch {
		case err == nil:
			ok++
		case errors.Is(err, model.ErrPaymentAlreadyReviewed):
			already++
		default:
			t.Fatalf("unexpected error %v", err)
		}
	}
	if ok != 1 || already != 1 {
		t.Errorf("errs %v; want one success and one payment_already_reviewed", errs)
	}
	if n := env.count(t, `SELECT count(*) FROM activity_logs WHERE action = 'payment.approved'`); n != 1 {
		t.Errorf("%d approvals logged, want 1", n)
	}
}
