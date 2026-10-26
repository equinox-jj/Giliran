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

// fakeGroups records its inputs and returns canned results.
type fakeGroups struct {
	detail    service.GroupDetail
	summaries []repository.GroupSummary
	members   []service.Member
	invite    service.Invite
	err       error

	called    string
	gotUser   uuid.UUID
	gotGroup  uuid.UUID
	gotNew    service.NewGroup
	gotChange repository.GroupChange
	gotFilter service.MyGroupsFilter
	gotOrder  []service.SlotPosition
	gotBank   [3]string
	gotData   []byte
}

func (f *fakeGroups) Create(_ context.Context, userID uuid.UUID, ng service.NewGroup) (service.GroupDetail, error) {
	f.called, f.gotUser, f.gotNew = "create", userID, ng
	return f.detail, f.err
}

func (f *fakeGroups) Get(_ context.Context, groupID, userID uuid.UUID) (service.GroupDetail, error) {
	f.called, f.gotGroup, f.gotUser = "get", groupID, userID
	return f.detail, f.err
}

func (f *fakeGroups) ListMine(_ context.Context, userID uuid.UUID, filter service.MyGroupsFilter) ([]repository.GroupSummary, error) {
	f.called, f.gotUser, f.gotFilter = "list_mine", userID, filter
	return f.summaries, f.err
}

func (f *fakeGroups) Update(_ context.Context, groupID, userID uuid.UUID, c repository.GroupChange) (service.GroupDetail, error) {
	f.called, f.gotGroup, f.gotUser, f.gotChange = "update", groupID, userID, c
	return f.detail, f.err
}

func (f *fakeGroups) SetPaymentInfo(_ context.Context, groupID, userID uuid.UUID, bank, number, holder string) (service.GroupDetail, error) {
	f.called, f.gotGroup, f.gotUser, f.gotBank = "payment_info", groupID, userID, [3]string{bank, number, holder}
	return f.detail, f.err
}

func (f *fakeGroups) UploadQRIS(_ context.Context, groupID, userID uuid.UUID, data []byte) (service.GroupDetail, error) {
	f.called, f.gotGroup, f.gotUser, f.gotData = "upload_qris", groupID, userID, data
	return f.detail, f.err
}

func (f *fakeGroups) DeleteQRIS(_ context.Context, groupID, userID uuid.UUID) error {
	f.called, f.gotGroup, f.gotUser = "delete_qris", groupID, userID
	return f.err
}

func (f *fakeGroups) SetFixedOrder(_ context.Context, groupID, userID uuid.UUID, order []service.SlotPosition) ([]service.Member, error) {
	f.called, f.gotGroup, f.gotUser, f.gotOrder = "fixed_order", groupID, userID, order
	return f.members, f.err
}

func (f *fakeGroups) Close(_ context.Context, groupID, userID uuid.UUID) (service.GroupDetail, error) {
	f.called, f.gotGroup, f.gotUser = "close", groupID, userID
	return f.detail, f.err
}

func (f *fakeGroups) ResetInvite(_ context.Context, groupID, userID uuid.UUID) (service.Invite, error) {
	f.called, f.gotGroup, f.gotUser = "reset_invite", groupID, userID
	return f.invite, f.err
}

// newGroupApp mounts the group routes as routes.Register does, minus rate
// limits.
func newGroupApp(groups GroupService) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &GroupController{groups: groups}
	auth := middleware.Auth(testTokens)
	app.Get("/api/v1/me/groups", auth, h.ListMine)
	app.Post("/api/v1/groups", auth, h.Create)
	g := app.Group("/api/v1/groups/:group_id", auth)
	g.Get("", h.Get)
	g.Patch("", h.Update)
	g.Put("/payment-info", h.SetPaymentInfo)
	g.Put("/payment-info/qris", h.UploadQRIS)
	g.Delete("/payment-info/qris", h.DeleteQRIS)
	g.Put("/fixed-order", h.SetFixedOrder)
	g.Post("/close", h.Close)
	g.Post("/invite-code/reset", h.ResetInvite)
	return app
}

func testGroupDetail(organizer bool) service.GroupDetail {
	now := time.Date(2026, 10, 26, 2, 0, 0, 0, time.UTC)
	bank, number, holder := "BCA", "1234567890", "Rina Susanti"
	qrisURL, merchant := "http://localhost:9000/giliran/qris/a.png?X-Amz-Signature=x", "WARUNG BU RINA"
	d := service.GroupDetail{
		Group: model.Group{
			ID: uuid.Must(uuid.NewV7()), OrganizerID: uuid.Must(uuid.NewV7()), Name: "Arisan RT 05", Amount: 150_000,
			PeriodType: model.PeriodTypeMonthly, TotalSlots: 10, DrawMethod: model.DrawMethodRandom,
			StartDate: time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC), ReminderDaysBefore: 2,
			Status: model.GroupStatusDraft, InviteCode: "K7P2QX9M",
			BankName: &bank, BankAccountNumber: &number, BankAccountHolder: &holder,
			CreatedAt: now, UpdatedAt: now,
		},
		Organizer:        service.UserRef{ID: uuid.Must(uuid.NewV7()), Name: "Rina Susanti"},
		Me:               model.GroupMember{ID: uuid.Must(uuid.NewV7()), Role: model.MemberRoleMember},
		FilledSlots:      3,
		QRISImageURL:     &qrisURL,
		QRISMerchantName: &merchant,
	}
	if organizer {
		d.Me.Role = model.MemberRoleOrganizer
		d.Invite = &service.Invite{Code: "K7P2QX9M", URL: "https://giliran.monai.my.id/j/K7P2QX9M"}
	}
	return d
}

func testMember(guest bool) service.Member {
	userID := uuid.Must(uuid.NewV7())
	name, phone, pos, won := "Ani", "+6281255554444", int16(2), int16(1)
	m := service.Member{MemberView: repository.MemberView{
		Member: model.GroupMember{
			ID: uuid.Must(uuid.NewV7()), GroupID: uuid.Must(uuid.NewV7()), UserID: &userID,
			Role: model.MemberRoleMember, Status: model.MemberStatusActive, JoinedAt: time.Now().UTC(),
		},
		SlotID: uuid.Must(uuid.NewV7()), SlotNo: 3, FixedOrderPosition: &pos, UserName: &name, WonPeriodNo: &won,
	}}
	if guest {
		m.Member.UserID, m.Member.GuestName, m.Member.GuestPhone, m.UserName = nil, &name, &phone, nil
	}
	return m
}

func TestGroupCreate(t *testing.T) {
	// Arrange
	fake := &fakeGroups{detail: testGroupDetail(true)}
	req, userID, _ := authed(t, http.MethodPost, "/api/v1/groups",
		`{"name":"Arisan RT 05","amount":150000,"period_type":"monthly","total_slots":10,"start_date":"2026-11-01","draw_method":"random"}`)

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 201 || fake.called != "create" || fake.gotUser != userID {
		t.Fatalf("status %d, service got %s for %s", resp.StatusCode, fake.called, fake.gotUser)
	}
	if loc := resp.Header.Get("Location"); loc != "/api/v1/groups/"+fake.detail.Group.ID.String() {
		t.Errorf("Location %q", loc)
	}
	want := service.NewGroup{
		Name: "Arisan RT 05", Amount: 150_000, PeriodType: model.PeriodTypeMonthly, TotalSlots: 10,
		DrawMethod: model.DrawMethodRandom, StartDate: time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC), ReminderDaysBefore: 2,
	}
	if fake.gotNew != want {
		t.Errorf("service got %+v, want %+v", fake.gotNew, want)
	}
	data := body["data"].(map[string]any)
	if data["pot_amount"] != float64(1_500_000) || data["start_date"] != "2026-11-01" || data["invite"].(map[string]any)["invite_code"] != "K7P2QX9M" {
		t.Errorf("data %v", data)
	}
}

func TestGroupCreateValidation(t *testing.T) {
	// Arrange
	tests := []struct {
		name      string
		body      string
		wantField string
	}{
		{"amount too low", `{"name":"Arisan","amount":5000,"period_type":"monthly","total_slots":10,"start_date":"2026-11-01","draw_method":"random"}`, "amount"},
		{"bad date", `{"name":"Arisan","amount":150000,"period_type":"monthly","total_slots":10,"start_date":"01/11/2026","draw_method":"random"}`, "start_date"},
		{"bad period type", `{"name":"Arisan","amount":150000,"period_type":"daily","total_slots":10,"start_date":"2026-11-01","draw_method":"random"}`, "period_type"},
		{"too many slots", `{"name":"Arisan","amount":150000,"period_type":"weekly","total_slots":51,"start_date":"2026-11-01","draw_method":"random"}`, "total_slots"},
		{"reminder too far", `{"name":"Arisan","amount":150000,"period_type":"weekly","total_slots":5,"start_date":"2026-11-01","draw_method":"random","reminder_days_before":8}`, "reminder_days_before"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeGroups{}
			req, _, _ := authed(t, http.MethodPost, "/api/v1/groups", tt.body)

			// Act
			resp, body := call(t, newGroupApp(fake), req)

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

func TestGroupGetForMember(t *testing.T) {
	// Arrange
	fake := &fakeGroups{detail: testGroupDetail(false)}
	req, userID, _ := authed(t, http.MethodGet, "/api/v1/groups/"+fake.detail.Group.ID.String(), "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotGroup != fake.detail.Group.ID || fake.gotUser != userID {
		t.Fatalf("status %d, service got %s for %s", resp.StatusCode, fake.gotGroup, fake.gotUser)
	}
	data := body["data"].(map[string]any)
	if data["invite"] != nil || data["payment_info"].(map[string]any)["qris_merchant_name"] != "WARUNG BU RINA" {
		t.Errorf("data %v", data)
	}
}

func TestGroupBadIDIsNotFound(t *testing.T) {
	// Arrange
	fake := &fakeGroups{}
	req, _, _ := authed(t, http.MethodGet, "/api/v1/groups/not-a-uuid", "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 404 || body["code"] != "group_not_found" || fake.called != "" {
		t.Errorf("status %d, code %v, service called %q", resp.StatusCode, body["code"], fake.called)
	}
}

func TestGroupUpdate(t *testing.T) {
	// Arrange
	fake := &fakeGroups{detail: testGroupDetail(true)}
	req, _, _ := authed(t, http.MethodPatch, "/api/v1/groups/"+fake.detail.Group.ID.String(),
		`{"name":"Arisan Kantor","period_type":"weekly","start_date":"2026-12-01"}`)

	// Act
	resp, _ := call(t, newGroupApp(fake), req)

	// Assert
	c := fake.gotChange
	if resp.StatusCode != 200 || *c.Name != "Arisan Kantor" || *c.PeriodType != model.PeriodTypeWeekly ||
		!c.StartDate.Equal(time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)) || c.Amount != nil {
		t.Errorf("status %d, change %+v", resp.StatusCode, c)
	}
}

func TestGroupUpdateErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		body       string
		serviceErr error
		wantStatus int
		wantCode   string
	}{
		{"empty body", `{}`, nil, 422, "validation_error"},
		{"locked after start", `{"amount":200000}`, model.ErrGroupNotDraft, 409, "group_not_draft"},
		{"member", `{"name":"Arisan Kantor"}`, model.ErrForbiddenRole, 403, "forbidden_role"},
		{"non-member", `{"name":"Arisan Kantor"}`, model.ErrGroupNotFound, 404, "group_not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeGroups{err: tt.serviceErr}
			req, _, _ := authed(t, http.MethodPatch, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String(), tt.body)

			// Act
			resp, body := call(t, newGroupApp(fake), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestGroupListMine(t *testing.T) {
	// Arrange
	periodID, periodNo, due := uuid.Must(uuid.NewV7()), int16(2), time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)
	paid := model.PaymentStatusPaid
	fake := &fakeGroups{summaries: []repository.GroupSummary{
		{
			ID: uuid.Must(uuid.NewV7()), Name: "Arisan RT 05", Amount: 150_000, PeriodType: model.PeriodTypeMonthly,
			Status: model.GroupStatusActive, TotalSlots: 10, MyRole: model.MemberRoleMember, FilledSlots: 10,
			CurrentPeriodID: &periodID, CurrentPeriodNo: &periodNo, NextDueDate: &due, NextDrawDate: &due,
			MyPaymentStatus: &paid, PaidCount: 7, PendingReviewCount: 2,
		},
		{
			ID: uuid.Must(uuid.NewV7()), Name: "Arisan Kantor", Amount: 100_000, PeriodType: model.PeriodTypeWeekly,
			Status: model.GroupStatusDraft, TotalSlots: 5, MyRole: model.MemberRoleOrganizer, FilledSlots: 1,
		},
	}}
	req, _, _ := authed(t, http.MethodGet, "/api/v1/me/groups?status=all", "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotFilter != service.MyGroupsAll {
		t.Fatalf("status %d, filter %q", resp.StatusCode, fake.gotFilter)
	}
	data := body["data"].([]any)
	running, draft := data[0].(map[string]any), data[1].(map[string]any)
	if running["paid_count"] != float64(7) || running["pending_review_count"] != nil || running["next_due_date"] != "2026-12-01" {
		t.Errorf("running group %v; review count is for organizers only", running)
	}
	if draft["paid_count"] != nil || draft["my_payment_status"] != nil || draft["current_period_no"] != nil {
		t.Errorf("draft group %v", draft)
	}
}

func TestGroupListMineDefaultsToActive(t *testing.T) {
	// Arrange
	fake := &fakeGroups{}
	req, _, _ := authed(t, http.MethodGet, "/api/v1/me/groups", "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotFilter != service.MyGroupsActive || len(body["data"].([]any)) != 0 {
		t.Errorf("status %d, filter %q, data %v", resp.StatusCode, fake.gotFilter, body["data"])
	}
}

func TestGroupSetPaymentInfo(t *testing.T) {
	// Arrange
	fake := &fakeGroups{detail: testGroupDetail(true)}
	req, _, _ := authed(t, http.MethodPut, "/api/v1/groups/"+fake.detail.Group.ID.String()+"/payment-info",
		`{"bank_name":"BCA","account_number":"1234567890","account_holder":"Rina Susanti"}`)

	// Act
	resp, _ := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.gotBank != [3]string{"BCA", "1234567890", "Rina Susanti"} {
		t.Errorf("status %d, service got %v", resp.StatusCode, fake.gotBank)
	}
}

func TestGroupSetPaymentInfoRejectsBadAccountNumber(t *testing.T) {
	// Arrange
	fake := &fakeGroups{}
	req, _, _ := authed(t, http.MethodPut, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String()+"/payment-info",
		`{"bank_name":"BCA","account_number":"12-34","account_holder":"Rina"}`)

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 422 || fake.called != "" || body["errors"].([]any)[0].(map[string]any)["field"] != "account_number" {
		t.Errorf("status %d, errors %v", resp.StatusCode, body["errors"])
	}
}

func qrisRequest(t *testing.T, groupID uuid.UUID, data []byte) *http.Request {
	t.Helper()
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	part, err := w.CreateFormFile("file", "qris.png")
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
	req := httptest.NewRequest(http.MethodPut, "/api/v1/groups/"+groupID.String()+"/payment-info/qris", &body)
	req.Header.Set(fiber.HeaderContentType, w.FormDataContentType())
	req.Header.Set(fiber.HeaderAuthorization, "Bearer "+token)
	return req
}

func TestGroupUploadQRIS(t *testing.T) {
	// Arrange
	fake := &fakeGroups{detail: testGroupDetail(true)}
	req := qrisRequest(t, fake.detail.Group.ID, []byte("png bytes"))

	// Act
	resp, _ := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || fake.called != "upload_qris" || string(fake.gotData) != "png bytes" {
		t.Errorf("status %d, service got %s with %q", resp.StatusCode, fake.called, fake.gotData)
	}
}

func TestGroupUploadQRISInvalidCode(t *testing.T) {
	// Arrange
	fake := &fakeGroups{err: model.NewValidationError(model.FieldError{Field: "file", Code: model.FieldInvalidQRIS, Message: "Not a QRIS code."})}
	req := qrisRequest(t, uuid.Must(uuid.NewV7()), []byte("png bytes"))

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	f := body["errors"].([]any)[0].(map[string]any)
	if resp.StatusCode != 422 || f["field"] != "file" || f["code"] != "invalid_qris" {
		t.Errorf("status %d, errors %v", resp.StatusCode, body["errors"])
	}
}

func TestGroupDeleteQRIS(t *testing.T) {
	// Arrange
	fake := &fakeGroups{}
	req, _, _ := authed(t, http.MethodDelete, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String()+"/payment-info/qris", "")

	// Act
	resp, _ := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 204 || fake.called != "delete_qris" {
		t.Errorf("status %d, service got %s", resp.StatusCode, fake.called)
	}
}

func TestGroupSetFixedOrder(t *testing.T) {
	// Arrange
	fake := &fakeGroups{members: []service.Member{testMember(false), testMember(true)}}
	a, b := uuid.Must(uuid.NewV7()), uuid.Must(uuid.NewV7())
	req, _, _ := authed(t, http.MethodPut, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String()+"/fixed-order",
		`{"order":[{"slot_id":"`+a.String()+`","position":2},{"slot_id":"`+b.String()+`","position":1}]}`)

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	want := []service.SlotPosition{{SlotID: a, Position: 2}, {SlotID: b, Position: 1}}
	if resp.StatusCode != 200 || len(fake.gotOrder) != 2 || fake.gotOrder[0] != want[0] || fake.gotOrder[1] != want[1] {
		t.Fatalf("status %d, order %v", resp.StatusCode, fake.gotOrder)
	}
	if data := body["data"].([]any); len(data) != 2 {
		t.Errorf("data %v", data)
	}
}

func TestGroupSetFixedOrderBadSlotID(t *testing.T) {
	// Arrange
	fake := &fakeGroups{}
	req, _, _ := authed(t, http.MethodPut, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String()+"/fixed-order",
		`{"order":[{"slot_id":"x","position":1},{"slot_id":"`+uuid.Must(uuid.NewV7()).String()+`","position":0}]}`)

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	errs := body["errors"].([]any)
	if resp.StatusCode != 422 || len(errs) != 2 || errs[0].(map[string]any)["field"] != "order[0].slot_id" || errs[1].(map[string]any)["field"] != "order[1].position" {
		t.Errorf("status %d, errors %v", resp.StatusCode, errs)
	}
}

func TestGroupClose(t *testing.T) {
	// Arrange
	fake := &fakeGroups{detail: testGroupDetail(true)}
	fake.detail.Group.Status = model.GroupStatusClosed
	closed := time.Now().UTC()
	fake.detail.Group.ClosedAt = &closed
	req, _, _ := authed(t, http.MethodPost, "/api/v1/groups/"+fake.detail.Group.ID.String()+"/close", "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 200 || body["data"].(map[string]any)["status"] != "closed" {
		t.Errorf("status %d, data %v", resp.StatusCode, body["data"])
	}
}

func TestGroupResetInvite(t *testing.T) {
	// Arrange
	fake := &fakeGroups{invite: service.Invite{Code: "Q2W3E4R5", URL: "https://giliran.monai.my.id/j/Q2W3E4R5"}}
	req, _, _ := authed(t, http.MethodPost, "/api/v1/groups/"+uuid.Must(uuid.NewV7()).String()+"/invite-code/reset", "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if data := body["data"].(map[string]any); resp.StatusCode != 200 || data["invite_code"] != "Q2W3E4R5" {
		t.Errorf("status %d, data %v", resp.StatusCode, data)
	}
}

func TestGroupWritesToClosedGroup(t *testing.T) {
	// Arrange
	closed := model.ErrGroupNotActive.WithDetail("The group is closed and read-only.")
	gid := uuid.Must(uuid.NewV7()).String()
	tests := []struct {
		name string
		req  func(t *testing.T) *http.Request
	}{
		{"payment info", func(t *testing.T) *http.Request {
			req, _, _ := authed(t, http.MethodPut, "/api/v1/groups/"+gid+"/payment-info",
				`{"bank_name":"BCA","account_number":"1234567890","account_holder":"Rina"}`)
			return req
		}},
		{"qris", func(t *testing.T) *http.Request { return qrisRequest(t, uuid.MustParse(gid), []byte("png bytes")) }},
		{"invite reset", func(t *testing.T) *http.Request {
			req, _, _ := authed(t, http.MethodPost, "/api/v1/groups/"+gid+"/invite-code/reset", "")
			return req
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &fakeGroups{err: closed}

			// Act
			resp, body := call(t, newGroupApp(fake), tt.req(t))

			// Assert
			if resp.StatusCode != 409 || body["code"] != "group_not_active" {
				t.Errorf("status %d, code %v; want 409 group_not_active", resp.StatusCode, body["code"])
			}
		})
	}
}

func TestGroupListMineRejectsUnknownStatus(t *testing.T) {
	// Arrange
	fake := &fakeGroups{}
	req, _, _ := authed(t, http.MethodGet, "/api/v1/me/groups?status=archived", "")

	// Act
	resp, body := call(t, newGroupApp(fake), req)

	// Assert
	if resp.StatusCode != 422 || fake.called != "" || body["errors"].([]any)[0].(map[string]any)["field"] != "status" {
		t.Errorf("status %d, errors %v, service called %q", resp.StatusCode, body["errors"], fake.called)
	}
}
