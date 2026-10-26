//go:build integration

package controller

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

func (f paymentFlow) periodsPath(rest string) string {
	return "/api/v1/groups/" + f.groupID.String() + "/periods/" + rest
}

// periodIDs returns the group's period IDs in order.
func (f paymentFlow) periodIDs(t *testing.T) []uuid.UUID {
	t.Helper()
	rows, err := f.pool.Query(context.Background(), `SELECT id FROM periods WHERE group_id = $1 ORDER BY period_no`, f.groupID)
	if err != nil {
		t.Fatalf("query periods: %v", err)
	}
	defer rows.Close()
	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			t.Fatalf("scan: %v", err)
		}
		out = append(out, id)
	}
	return out
}

// payAll marks every payment of the period paid over HTTP.
func (f paymentFlow) payAll(t *testing.T, periodID uuid.UUID) {
	t.Helper()
	rows, err := f.pool.Query(context.Background(), `SELECT id FROM payments WHERE period_id = $1`, periodID)
	if err != nil {
		t.Fatalf("query payments: %v", err)
	}
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			t.Fatalf("scan: %v", err)
		}
		ids = append(ids, id)
	}
	rows.Close()
	for _, id := range ids {
		path := "/api/v1/groups/" + f.groupID.String() + "/payments/" + id.String() + "/mark-paid"
		req := f.as(t, jsonRequest(path, `{"method":"cash"}`), f.rina, "pay-"+id.String())
		if resp, body := f.send(t, req); resp.StatusCode != 200 {
			t.Fatalf("mark-paid: %d %v", resp.StatusCode, body)
		}
	}
}

func (f paymentFlow) drawPeriod(t *testing.T, periodID uuid.UUID) map[string]any {
	t.Helper()
	req := f.as(t, jsonRequest(f.periodsPath(periodID.String()+"/draw"), ""), f.rina, "draw-"+periodID.String())
	resp, body := f.send(t, req)
	if resp.StatusCode != 201 {
		t.Fatalf("draw: %d %v", resp.StatusCode, body)
	}
	return body["data"].(map[string]any)
}

func (f paymentFlow) recordPayout(t *testing.T, periodID uuid.UUID) {
	t.Helper()
	req := f.as(t, payoutRequest(t, f.periodsPath(periodID.String()+"/payout"), nil, nil), f.rina, "payout-"+periodID.String())
	if resp, body := f.send(t, req); resp.StatusCode != 201 {
		t.Fatalf("payout: %d %v", resp.StatusCode, body)
	}
}

func TestDrawFlowIncompleteThenConfirmWithSameKey(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)
	f.clock.Set(time.Date(2027, time.January, 1, 3, 0, 0, 0, time.UTC))
	first := f.periodIDs(t)[0]
	path := f.periodsPath(first.String() + "/draw")
	resp, body := f.send(t, f.as(t, jsonRequest(path, ""), f.rina, "draw-key-0001"))
	if resp.StatusCode != 409 || body["code"] != "payments_incomplete" || body["paid_count"] != float64(0) || body["total_count"] != float64(2) {
		t.Fatalf("first draw: %d %v", resp.StatusCode, body)
	}

	// Act
	resp, body = f.send(t, f.as(t, jsonRequest(path, `{"confirm_incomplete":true}`), f.rina, "draw-key-0001"))

	// Assert
	if resp.StatusCode != 201 || body["data"].(map[string]any)["status"] != "drawn" {
		t.Fatalf("confirmed draw: %d %v", resp.StatusCode, body)
	}
}

func TestDrawFlowRetryReplaysDraw(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)
	f.clock.Set(time.Date(2027, time.January, 1, 3, 0, 0, 0, time.UTC))
	first := f.periodIDs(t)[0]
	f.payAll(t, first)
	drawn := f.drawPeriod(t, first)

	// Act
	resp, body := f.send(t, f.as(t, jsonRequest(f.periodsPath(first.String()+"/draw"), ""), f.rina, "draw-"+first.String()))

	// Assert
	if resp.StatusCode != 201 || resp.Header.Get(HeaderIdempotentReplayed) != "true" {
		t.Fatalf("retry: %d, replayed %q", resp.StatusCode, resp.Header.Get(HeaderIdempotentReplayed))
	}
	if body["data"].(map[string]any)["verification_code"] != drawn["verification_code"] {
		t.Errorf("retry shows code %v, want %v", body["data"].(map[string]any)["verification_code"], drawn["verification_code"])
	}
	if n := f.count(t, "draw.completed"); n != 1 {
		t.Errorf("%d draws logged, want 1", n)
	}
}

func TestDrawFlowFullCycleIsPubliclyVerifiable(t *testing.T) {
	// Arrange
	t.Parallel()
	f := newPaymentFlow(t)
	f.clock.Set(time.Date(2027, time.January, 1, 3, 0, 0, 0, time.UTC))
	ids := f.periodIDs(t)
	var codes []string
	for _, id := range ids {
		f.payAll(t, id)
		codes = append(codes, f.drawPeriod(t, id)["verification_code"].(string))
		f.recordPayout(t, id)
	}

	// Act
	resp, body := f.send(t, httptest.NewRequest(http.MethodGet, "/api/v1/public/draws/"+codes[1], nil))

	// Assert
	if resp.StatusCode != 200 {
		t.Fatalf("public draw: %d %v", resp.StatusCode, body)
	}
	data := body["data"].(map[string]any)
	if data["hash_matches"] != true || data["recomputed_winner_matches"] != true || data["period_no"] != float64(2) {
		t.Errorf("public draw %v", data)
	}
	if n := len(data["eligible_slots"].([]any)); n != 1 {
		t.Errorf("period 2 had %d eligible slots, want 1", n)
	}
	var status string
	if err := f.pool.QueryRow(context.Background(), `SELECT status FROM groups WHERE id = $1`, f.groupID).Scan(&status); err != nil || status != "completed" {
		t.Errorf("group %s (%v), want completed", status, err)
	}
	page, err := f.app.Test(httptest.NewRequest(http.MethodGet, "/v/"+codes[0], nil))
	if err != nil {
		t.Fatal(err)
	}
	html, _ := io.ReadAll(page.Body)
	if page.StatusCode != 200 || !strings.Contains(string(html), "Arisan RT 05") {
		t.Errorf("page %d", page.StatusCode)
	}
}
