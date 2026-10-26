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
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
	"github.com/equinox-jj/Giliran/backend/pkg/validation"
)

// fakeMembers implements MemberService, LeaveService and OwnershipService,
// recording its inputs and returning canned results.
type fakeMembers struct {
	member   service.Member
	members  []service.Member
	preview  service.InvitePreview
	link     service.ClaimLink
	leave    service.LeaveRequest
	leaves   []service.LeaveRequest
	transfer service.OwnershipTransfer
	err      error

	called    string
	gotUser   uuid.UUID
	gotGroup  uuid.UUID
	gotID     uuid.UUID
	gotCode   string
	gotAll    bool
	gotName   string
	gotPhone  *string
	gotChange service.GuestChange
	gotReason *string
	gotStatus *model.LeaveRequestStatus
}

func (f *fakeMembers) PreviewInvite(_ context.Context, userID uuid.UUID, code string) (service.InvitePreview, error) {
	f.called, f.gotUser, f.gotCode = "preview", userID, code
	return f.preview, f.err
}

func (f *fakeMembers) Join(_ context.Context, userID uuid.UUID, code string) (service.Member, error) {
	f.called, f.gotUser, f.gotCode = "join", userID, code
	return f.member, f.err
}

func (f *fakeMembers) List(_ context.Context, groupID, userID uuid.UUID, includeInactive bool) ([]service.Member, error) {
	f.called, f.gotGroup, f.gotUser, f.gotAll = "list", groupID, userID, includeInactive
	return f.members, f.err
}

func (f *fakeMembers) Get(_ context.Context, groupID, userID, memberID uuid.UUID) (service.Member, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID = "get", groupID, userID, memberID
	return f.member, f.err
}

func (f *fakeMembers) AddGuest(_ context.Context, groupID, userID uuid.UUID, name string, phone *string) (service.Member, error) {
	f.called, f.gotGroup, f.gotUser, f.gotName, f.gotPhone = "add_guest", groupID, userID, name, phone
	return f.member, f.err
}

func (f *fakeMembers) UpdateGuest(_ context.Context, groupID, userID, memberID uuid.UUID, c service.GuestChange) (service.Member, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID, f.gotChange = "update_guest", groupID, userID, memberID, c
	return f.member, f.err
}

func (f *fakeMembers) Remove(_ context.Context, groupID, userID, memberID uuid.UUID) error {
	f.called, f.gotGroup, f.gotUser, f.gotID = "remove", groupID, userID, memberID
	return f.err
}

func (f *fakeMembers) CreateClaimLink(_ context.Context, groupID, userID, memberID uuid.UUID) (service.ClaimLink, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID = "claim_link", groupID, userID, memberID
	return f.link, f.err
}

func (f *fakeMembers) Claim(_ context.Context, userID uuid.UUID, token string) (service.Member, error) {
	f.called, f.gotUser, f.gotCode = "claim", userID, token
	return f.member, f.err
}

func (f *fakeMembers) Request(_ context.Context, groupID, userID uuid.UUID, reason *string) (service.LeaveRequest, error) {
	f.called, f.gotGroup, f.gotUser, f.gotReason = "request_leave", groupID, userID, reason
	return f.leave, f.err
}

func (f *fakeMembers) Approve(_ context.Context, groupID, userID, requestID uuid.UUID) (service.LeaveRequest, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID = "approve_leave", groupID, userID, requestID
	return f.leave, f.err
}

func (f *fakeMembers) Reject(_ context.Context, groupID, userID, requestID uuid.UUID, reason *string) (service.LeaveRequest, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID, f.gotReason = "reject_leave", groupID, userID, requestID, reason
	return f.leave, f.err
}

func (f *fakeMembers) Offer(_ context.Context, groupID, userID, toMemberID uuid.UUID) (service.OwnershipTransfer, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID = "offer", groupID, userID, toMemberID
	return f.transfer, f.err
}

func (f *fakeMembers) Accept(_ context.Context, groupID, userID, transferID uuid.UUID) (service.OwnershipTransfer, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID = "accept", groupID, userID, transferID
	return f.transfer, f.err
}

func (f *fakeMembers) Decline(_ context.Context, groupID, userID, transferID uuid.UUID) (service.OwnershipTransfer, error) {
	f.called, f.gotGroup, f.gotUser, f.gotID = "decline", groupID, userID, transferID
	return f.transfer, f.err
}

// fakeLeaveList adapts fakeMembers to LeaveService, whose List clashes with
// MemberService.List.
type fakeLeaveList struct{ *fakeMembers }

func (f fakeLeaveList) List(_ context.Context, groupID, userID uuid.UUID, status *model.LeaveRequestStatus) ([]service.LeaveRequest, error) {
	f.called, f.gotGroup, f.gotUser, f.gotStatus = "list_leaves", groupID, userID, status
	return f.leaves, f.err
}

// newMemberApp mounts the member routes as routes.Register does, minus rate
// limits.
func newMemberApp(f *fakeMembers) *fiber.App {
	app := fiber.New(fiber.Config{
		ErrorHandler:    response.ErrorHandler(discardLogger()),
		StructValidator: validation.New(),
	})
	app.Use(middleware.RequestID())
	h := &MemberController{members: f, leaves: fakeLeaveList{f}, ownership: f}
	auth := middleware.Auth(testTokens)
	app.Get("/api/v1/invites/:invite_code", auth, h.PreviewInvite)
	app.Post("/api/v1/invites/:invite_code/join", auth, h.Join)
	app.Post("/api/v1/claims/:claim_token", auth, h.Claim)
	g := app.Group("/api/v1/groups/:group_id", auth)
	g.Get("/members", h.List)
	g.Post("/guests", h.AddGuest)
	g.Get("/members/:member_id", h.Get)
	g.Patch("/members/:member_id", h.UpdateGuest)
	g.Delete("/members/:member_id", h.Remove)
	g.Post("/members/:member_id/claim-link", h.CreateClaimLink)
	g.Get("/leave-requests", h.ListLeaveRequests)
	g.Post("/leave-requests", h.RequestLeave)
	g.Post("/leave-requests/:request_id/approve", h.ApproveLeave)
	g.Post("/leave-requests/:request_id/reject", h.RejectLeave)
	g.Post("/ownership-transfers", h.OfferOwnership)
	g.Post("/ownership-transfers/:transfer_id/accept", h.AcceptOwnership)
	g.Post("/ownership-transfers/:transfer_id/decline", h.DeclineOwnership)
	return app
}

func groupPath(rest string) string {
	return "/api/v1/groups/" + uuid.Must(uuid.NewV7()).String() + rest
}

func testLeave() service.LeaveRequest {
	reason := "Pindah kota"
	reviewed := time.Now().UTC()
	reviewer := service.UserRef{ID: uuid.Must(uuid.NewV7()), Name: "Rina Susanti"}
	return service.LeaveRequest{
		Request: model.LeaveRequest{
			ID: uuid.Must(uuid.NewV7()), Reason: &reason, Status: model.LeaveRequestStatusApproved,
			ReviewedBy: &reviewer.ID, ReviewedAt: &reviewed, CreatedAt: reviewed,
		},
		Member:     testMember(false),
		ReviewedBy: &reviewer,
	}
}

func testTransfer() service.OwnershipTransfer {
	now := time.Now().UTC()
	return service.OwnershipTransfer{
		Transfer: model.OwnershipTransfer{
			ID: uuid.Must(uuid.NewV7()), Status: model.OwnershipTransferStatusPending,
			ExpiresAt: now.Add(model.OwnershipTransferTTL), CreatedAt: now,
		},
		From: service.UserRef{ID: uuid.Must(uuid.NewV7()), Name: "Rina Susanti"},
		To:   testMember(false),
	}
}

func TestMemberInvitePreview(t *testing.T) {
	// Arrange
	f := &fakeMembers{preview: service.InvitePreview{
		Group:     testGroupDetail(false).Group,
		Organizer: service.UserRef{ID: uuid.Must(uuid.NewV7()), Name: "Rina Susanti"},
		CanJoin:   true,
	}}
	req, userID, _ := authed(t, http.MethodGet, "/api/v1/invites/K7P2QX9M", "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 200 || f.gotCode != "K7P2QX9M" || f.gotUser != userID {
		t.Fatalf("status %d, service got %q for %s", resp.StatusCode, f.gotCode, f.gotUser)
	}
	if data := body["data"].(map[string]any); data["can_join"] != true || data["group_name"] != "Arisan RT 05" {
		t.Errorf("data %v", data)
	}
}

func TestMemberInviteMalformedCode(t *testing.T) {
	// Arrange
	f := &fakeMembers{}
	req, _, _ := authed(t, http.MethodGet, "/api/v1/invites/short", "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 404 || body["code"] != "invite_not_found" || f.called != "" {
		t.Errorf("status %d, code %v, service called %q", resp.StatusCode, body["code"], f.called)
	}
}

func TestMemberJoin(t *testing.T) {
	// Arrange
	f := &fakeMembers{member: testMember(false)}
	req, _, _ := authed(t, http.MethodPost, "/api/v1/invites/K7P2QX9M/join", "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	want := "/api/v1/groups/" + f.member.Member.GroupID.String() + "/members/" + f.member.Member.ID.String()
	if resp.StatusCode != 201 || resp.Header.Get("Location") != want {
		t.Fatalf("status %d, Location %q", resp.StatusCode, resp.Header.Get("Location"))
	}
	data := body["data"].(map[string]any)
	if data["display_name"] != "Ani" || data["is_guest"] != false || data["has_won"] != true || data["user"].(map[string]any)["name"] != "Ani" {
		t.Errorf("data %v", data)
	}
}

func TestMemberJoinErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		err        error
		wantStatus int
		wantCode   string
	}{
		{"full", model.ErrGroupFull, 409, "group_full"},
		{"already a member", model.ErrAlreadyMember, 409, "already_member"},
		{"reset code", model.ErrInviteNotFound, 404, "invite_not_found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := &fakeMembers{err: tt.err}
			req, _, _ := authed(t, http.MethodPost, "/api/v1/invites/K7P2QX9M/join", "")

			// Act
			resp, body := call(t, newMemberApp(f), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want %d %s", resp.StatusCode, body["code"], tt.wantStatus, tt.wantCode)
			}
		})
	}
}

func TestMemberList(t *testing.T) {
	// Arrange
	f := &fakeMembers{members: []service.Member{testMember(false), testMember(true)}}
	req, _, _ := authed(t, http.MethodGet, groupPath("/members?status=all"), "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	data := body["data"].([]any)
	guest := data[1].(map[string]any)
	if resp.StatusCode != 200 || !f.gotAll || guest["user"] != nil || guest["is_guest"] != true || guest["guest_phone"] != "+6281255554444" {
		t.Errorf("status %d, all %v, guest %v", resp.StatusCode, f.gotAll, guest)
	}
}

func TestMemberGet(t *testing.T) {
	// Arrange
	f := &fakeMembers{member: testMember(true)}
	memberID := uuid.Must(uuid.NewV7())
	req, _, _ := authed(t, http.MethodGet, groupPath("/members/"+memberID.String()), "")

	// Act
	resp, _ := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 200 || f.gotID != memberID {
		t.Errorf("status %d, service got %s", resp.StatusCode, f.gotID)
	}
}

func TestMemberAddGuest(t *testing.T) {
	// Arrange
	f := &fakeMembers{member: testMember(true)}
	req, _, _ := authed(t, http.MethodPost, groupPath("/guests"), `{"name":"Ani","phone":"+6281255554444"}`)

	// Act
	resp, _ := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 201 || f.gotName != "Ani" || f.gotPhone == nil || *f.gotPhone != "+6281255554444" || resp.Header.Get("Location") == "" {
		t.Errorf("status %d, service got %q %v", resp.StatusCode, f.gotName, f.gotPhone)
	}
}

func TestMemberUpdateGuest(t *testing.T) {
	// Arrange
	tests := []struct {
		name      string
		body      string
		wantPhone bool
		wantName  bool
	}{
		{"remove phone", `{"phone":null}`, true, false},
		{"rename only", `{"name":"Ani Wijaya"}`, false, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := &fakeMembers{member: testMember(true)}
			req, _, _ := authed(t, http.MethodPatch, groupPath("/members/"+uuid.Must(uuid.NewV7()).String()), tt.body)

			// Act
			resp, _ := call(t, newMemberApp(f), req)

			// Assert
			c := f.gotChange
			if resp.StatusCode != 200 || c.SetPhone != tt.wantPhone || c.Phone != nil || (c.Name != nil) != tt.wantName {
				t.Errorf("status %d, change %+v", resp.StatusCode, c)
			}
		})
	}
}

func TestMemberUpdateGuestEmpty(t *testing.T) {
	// Arrange
	f := &fakeMembers{}
	req, _, _ := authed(t, http.MethodPatch, groupPath("/members/"+uuid.Must(uuid.NewV7()).String()), `{}`)

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 422 || body["code"] != "validation_error" || f.called != "" {
		t.Errorf("status %d, code %v, service called %q", resp.StatusCode, body["code"], f.called)
	}
}

func TestMemberRemove(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		err        error
		wantStatus int
	}{
		{"removed", nil, 204},
		{"has won", model.ErrObligationsOutstanding, 409},
		{"organizer", model.ErrOrganizerCannotLeave, 409},
		{"by a member", model.ErrForbiddenRole, 403},
		{"unknown member", model.ErrMemberNotFound, 404},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := &fakeMembers{err: tt.err}
			req, _, _ := authed(t, http.MethodDelete, groupPath("/members/"+uuid.Must(uuid.NewV7()).String()), "")

			// Act
			resp, _ := call(t, newMemberApp(f), req)

			// Assert
			if resp.StatusCode != tt.wantStatus || f.called != "remove" {
				t.Errorf("status %d, want %d", resp.StatusCode, tt.wantStatus)
			}
		})
	}
}

func TestMemberCreateClaimLink(t *testing.T) {
	// Arrange
	f := &fakeMembers{link: service.ClaimLink{URL: "https://giliran.monai.my.id/c/" + strings.Repeat("a", 43), ExpiresAt: time.Now().UTC()}}
	req, _, _ := authed(t, http.MethodPost, groupPath("/members/"+uuid.Must(uuid.NewV7()).String()+"/claim-link"), "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if data := body["data"].(map[string]any); resp.StatusCode != 201 || data["claim_url"] != f.link.URL {
		t.Errorf("status %d, data %v", resp.StatusCode, data)
	}
}

func TestMemberClaim(t *testing.T) {
	// Arrange
	f := &fakeMembers{member: testMember(false)}
	token := strings.Repeat("aB3_-", 9)
	req, userID, _ := authed(t, http.MethodPost, "/api/v1/claims/"+token, "")

	// Act
	resp, _ := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 200 || f.gotCode != token || f.gotUser != userID {
		t.Errorf("status %d, service got %q for %s", resp.StatusCode, f.gotCode, f.gotUser)
	}
}

func TestMemberClaimMalformedToken(t *testing.T) {
	// Arrange
	f := &fakeMembers{}
	req, _, _ := authed(t, http.MethodPost, "/api/v1/claims/"+strings.Repeat("a", 32)+"!", "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 404 || body["code"] != "claim_not_found" || f.called != "" {
		t.Errorf("status %d, code %v", resp.StatusCode, body["code"])
	}
}

func TestMemberListLeaveRequests(t *testing.T) {
	// Arrange
	f := &fakeMembers{leaves: []service.LeaveRequest{testLeave()}}
	req, _, _ := authed(t, http.MethodGet, groupPath("/leave-requests?status=approved"), "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 200 || f.gotStatus == nil || *f.gotStatus != model.LeaveRequestStatusApproved {
		t.Fatalf("status %d, filter %v", resp.StatusCode, f.gotStatus)
	}
	lr := body["data"].([]any)[0].(map[string]any)
	if lr["member"].(map[string]any)["slot_no"] != float64(3) || lr["reviewed_by"].(map[string]any)["name"] != "Rina Susanti" {
		t.Errorf("leave request %v", lr)
	}
}

func TestMemberRequestLeave(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		body       string
		wantReason bool
	}{
		{"with reason", `{"reason":"Pindah kota"}`, true},
		{"no body", "", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := &fakeMembers{leave: testLeave()}
			req, _, _ := authed(t, http.MethodPost, groupPath("/leave-requests"), tt.body)

			// Act
			resp, _ := call(t, newMemberApp(f), req)

			// Assert
			if resp.StatusCode != 201 || f.called != "request_leave" || (f.gotReason != nil) != tt.wantReason {
				t.Errorf("status %d, service got %s with reason %v", resp.StatusCode, f.called, f.gotReason)
			}
		})
	}
}

func TestMemberRequestLeaveErrors(t *testing.T) {
	// Arrange
	tests := []struct {
		name     string
		err      error
		wantCode string
	}{
		{"organizer", model.ErrOrganizerCannotLeave, "organizer_cannot_leave"},
		{"past winner owes", model.ErrObligationsOutstanding, "obligations_outstanding"},
		{"already pending", model.ErrPendingRequestExists, "pending_request_exists"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := &fakeMembers{err: tt.err}
			req, _, _ := authed(t, http.MethodPost, groupPath("/leave-requests"), "")

			// Act
			resp, body := call(t, newMemberApp(f), req)

			// Assert
			if resp.StatusCode != 409 || body["code"] != tt.wantCode {
				t.Errorf("status %d code %v, want 409 %s", resp.StatusCode, body["code"], tt.wantCode)
			}
		})
	}
}

func TestMemberReviewLeave(t *testing.T) {
	// Arrange
	tests := []struct {
		name       string
		action     string
		body       string
		wantCalled string
	}{
		{"approve", "approve", "", "approve_leave"},
		{"reject with reason", "reject", `{"reason":"Masih ada giliran"}`, "reject_leave"},
		{"reject without body", "reject", "", "reject_leave"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := &fakeMembers{leave: testLeave()}
			requestID := uuid.Must(uuid.NewV7())
			req, _, _ := authed(t, http.MethodPost, groupPath("/leave-requests/"+requestID.String()+"/"+tt.action), tt.body)

			// Act
			resp, _ := call(t, newMemberApp(f), req)

			// Assert
			if resp.StatusCode != 200 || f.called != tt.wantCalled || f.gotID != requestID {
				t.Errorf("status %d, service got %s for %s", resp.StatusCode, f.called, f.gotID)
			}
		})
	}
}

func TestMemberApproveLeaveNotPending(t *testing.T) {
	// Arrange
	f := &fakeMembers{err: model.ErrRequestNotPending}
	req, _, _ := authed(t, http.MethodPost, groupPath("/leave-requests/"+uuid.Must(uuid.NewV7()).String()+"/approve"), "")

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 409 || body["code"] != "request_not_pending" {
		t.Errorf("status %d, code %v", resp.StatusCode, body["code"])
	}
}

func TestMemberOfferOwnership(t *testing.T) {
	// Arrange
	f := &fakeMembers{transfer: testTransfer()}
	to := uuid.Must(uuid.NewV7())
	req, _, _ := authed(t, http.MethodPost, groupPath("/ownership-transfers"), `{"to_member_id":"`+to.String()+`"}`)

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 201 || f.gotID != to {
		t.Fatalf("status %d, service got %s", resp.StatusCode, f.gotID)
	}
	if data := body["data"].(map[string]any); data["status"] != "pending" || data["from_user"].(map[string]any)["name"] != "Rina Susanti" {
		t.Errorf("data %v", data)
	}
}

func TestMemberOfferOwnershipBadTarget(t *testing.T) {
	// Arrange
	f := &fakeMembers{}
	req, _, _ := authed(t, http.MethodPost, groupPath("/ownership-transfers"), `{"to_member_id":"nope"}`)

	// Act
	resp, body := call(t, newMemberApp(f), req)

	// Assert
	if resp.StatusCode != 422 || f.called != "" || body["errors"].([]any)[0].(map[string]any)["field"] != "to_member_id" {
		t.Errorf("status %d, errors %v", resp.StatusCode, body["errors"])
	}
}

func TestMemberRespondOwnership(t *testing.T) {
	// Arrange
	tests := []struct {
		action     string
		wantCalled string
		wantStatus model.OwnershipTransferStatus
	}{
		{"accept", "accept", model.OwnershipTransferStatusAccepted},
		{"decline", "decline", model.OwnershipTransferStatusDeclined},
	}
	for _, tt := range tests {
		t.Run(tt.action, func(t *testing.T) {
			f := &fakeMembers{transfer: testTransfer()}
			f.transfer.Transfer.Status = tt.wantStatus
			responded := time.Now().UTC()
			f.transfer.Transfer.RespondedAt = &responded
			transferID := uuid.Must(uuid.NewV7())
			req, _, _ := authed(t, http.MethodPost, groupPath("/ownership-transfers/"+transferID.String()+"/"+tt.action), "")

			// Act
			resp, body := call(t, newMemberApp(f), req)

			// Assert
			if resp.StatusCode != 200 || f.called != tt.wantCalled || f.gotID != transferID || body["data"].(map[string]any)["status"] != string(tt.wantStatus) {
				t.Errorf("status %d, service got %s for %s, data %v", resp.StatusCode, f.called, f.gotID, body["data"])
			}
		})
	}
}
