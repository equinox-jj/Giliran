//go:build integration

package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image/png"
	"io"
	"log/slog"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/qris"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

var (
	sari  = firebase.Identity{UID: "uid-sari", Phone: "+6281277776666"}
	joko  = firebase.Identity{UID: "uid-joko", Phone: "+6281244443333"}
	start = utils.Date(2026, time.November, 1)
)

type groupEnv struct {
	authEnv
	groups    *GroupService
	members   *MemberService
	leaves    *LeaveService
	ownership *OwnershipService
	store     *memStore
	jobs      *jobs.Enqueuer
}

func newGroupEnv(t *testing.T) groupEnv {
	t.Helper()
	auth := newAuthEnv(t, fakeVerifier{"rina": rina, "budi": budi, "sari": sari, "joko": joko})
	jakarta, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		t.Fatalf("LoadLocation: %v", err)
	}
	cfg := &config.Config{
		App:   config.App{PublicBaseURL: "https://giliran.test/", Location: jakarta},
		MinIO: config.MinIO{UploadMaxBytes: 5 << 20},
	}
	tx := repository.NewTxManager(auth.pool)
	users := repository.NewUserRepository(tx)
	groups := repository.NewGroupRepository(tx)
	members := repository.NewMemberRepository(tx)
	leaves := repository.NewLeaveRequestRepository(tx)
	transfers := repository.NewOwnershipTransferRepository(tx)
	periods := repository.NewPeriodRepository(tx)
	payments := repository.NewPaymentRepository(tx)
	authz := NewAuthz(groups, members)
	activity := NewActivity(repository.NewActivityRepository(tx), auth.clock)
	store := newMemStore()
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	return groupEnv{
		authEnv:   auth,
		jobs:      newTestEnqueuer(t, auth.pool),
		groups:    NewGroupService(tx, groups, members, leaves, transfers, periods, payments, users, authz, activity, store, auth.clock, log, cfg),
		members:   NewMemberService(tx, groups, members, leaves, transfers, users, authz, activity, store, auth.clock, cfg),
		leaves:    NewLeaveService(tx, members, leaves, transfers, users, authz, activity, store, auth.clock),
		ownership: NewOwnershipService(tx, groups, members, leaves, transfers, users, authz, activity, store, auth.clock),
		store:     store,
	}
}

// user signs idToken in and returns the user's ID.
func (e groupEnv) user(t *testing.T, idToken string) uuid.UUID {
	t.Helper()
	return e.signIn(t, idToken).Profile.User.ID
}

func (e groupEnv) create(t *testing.T, organizer uuid.UUID, slots int16, method model.DrawMethod) GroupDetail {
	t.Helper()
	d, err := e.groups.Create(context.Background(), organizer, NewGroup{
		Name: "Arisan RT 05", Amount: 150_000, PeriodType: model.PeriodTypeMonthly,
		TotalSlots: slots, DrawMethod: method, StartDate: start, ReminderDaysBefore: 2,
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	return d
}

func (e groupEnv) join(t *testing.T, userID uuid.UUID, code string) Member {
	t.Helper()
	m, err := e.members.Join(context.Background(), userID, code)
	if err != nil {
		t.Fatalf("Join: %v", err)
	}
	return m
}

func (e groupEnv) guest(t *testing.T, groupID, organizer uuid.UUID, name string, phone *string) Member {
	t.Helper()
	m, err := e.members.AddGuest(context.Background(), groupID, organizer, name, phone)
	if err != nil {
		t.Fatalf("AddGuest: %v", err)
	}
	return m
}

// actions lists the group's activity log actions, oldest first.
func (e groupEnv) actions(t *testing.T, groupID uuid.UUID) []string {
	t.Helper()
	rows, err := e.pool.Query(context.Background(), `SELECT action FROM activity_logs WHERE group_id = $1 ORDER BY id`, groupID)
	if err != nil {
		t.Fatalf("query activity: %v", err)
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var a string
		if err := rows.Scan(&a); err != nil {
			t.Fatalf("scan: %v", err)
		}
		out = append(out, a)
	}
	return out
}

// lastLog returns the newest entry's before and after JSON.
func (e groupEnv) lastLog(t *testing.T, groupID uuid.UUID) (string, string) {
	t.Helper()
	var before, after *string
	err := e.pool.QueryRow(context.Background(),
		`SELECT before::text, after::text FROM activity_logs WHERE group_id = $1 ORDER BY id DESC LIMIT 1`, groupID).Scan(&before, &after)
	if err != nil {
		t.Fatalf("query activity: %v", err)
	}
	deref := func(s *string) string {
		if s == nil {
			return ""
		}
		return *s
	}
	return deref(before), deref(after)
}

// activate marks a group as started without opening any period, for tests
// that only need an active group.
func (e groupEnv) activate(t *testing.T, groupID uuid.UUID) {
	t.Helper()
	if _, err := e.pool.Exec(context.Background(), `UPDATE groups SET status = 'active', started_at = now() WHERE id = $1`, groupID); err != nil {
		t.Fatalf("activate: %v", err)
	}
}

func slotNos(members []Member) map[string]int16 {
	out := map[string]int16{}
	for _, m := range members {
		out[m.DisplayName()] = m.SlotNo
	}
	return out
}

func wantErr(t *testing.T, err, want error) {
	t.Helper()
	if !errors.Is(err, want) {
		t.Fatalf("err %v, want %v", err, want)
	}
}

func TestGroupCreate(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")

	// Act
	d, err := env.groups.Create(context.Background(), rinaID, NewGroup{
		Name: "  Arisan RT 05  ", Amount: 150_000, PeriodType: model.PeriodTypeMonthly,
		TotalSlots: 10, DrawMethod: model.DrawMethodRandom, StartDate: start, ReminderDaysBefore: 2,
	})

	// Assert
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	g := d.Group
	if g.Name != "Arisan RT 05" || g.Status != model.GroupStatusDraft || g.OrganizerID != rinaID || len(g.InviteCode) != 8 {
		t.Errorf("group %+v", g)
	}
	if d.Me.Role != model.MemberRoleOrganizer || d.FilledSlots != 1 || d.Invite == nil || d.Invite.URL != "https://giliran.test/j/"+g.InviteCode {
		t.Errorf("detail %+v, invite %+v", d, d.Invite)
	}
	slots, err := env.groups.groups.ListSlots(context.Background(), g.ID)
	if err != nil || len(slots) != 10 || slots[0].SlotNo != 1 || slots[9].SlotNo != 10 {
		t.Fatalf("slots %v, %v", slots, err)
	}
	members, err := env.members.List(context.Background(), g.ID, rinaID, false)
	if err != nil || len(members) != 1 || members[0].SlotNo != 1 || members[0].Member.ID != d.Me.ID {
		t.Errorf("members %+v, %v", members, err)
	}
	if got := env.actions(t, g.ID); !slices.Equal(got, []string{"group.created"}) {
		t.Errorf("activity %v", got)
	}
}

func TestGroupCreateRejectsPastStartDate(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")

	// Act
	_, err := env.groups.Create(context.Background(), rinaID, NewGroup{
		Name: "Arisan RT 05", Amount: 150_000, PeriodType: model.PeriodTypeMonthly,
		TotalSlots: 10, DrawMethod: model.DrawMethodRandom, StartDate: utils.Date(2026, time.October, 25),
	})

	// Assert
	var verr *model.Error
	if !errors.As(err, &verr) || verr.Code != "validation_error" || verr.Fields[0].Field != "start_date" {
		t.Errorf("err %v, want validation_error on start_date", err)
	}
}

func TestGroupGetHidesGroupFromNonMembers(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	d := env.create(t, env.user(t, "rina"), 5, model.DrawMethodRandom)
	budiID := env.user(t, "budi")

	// Act
	_, err := env.groups.Get(context.Background(), d.Group.ID, budiID)

	// Assert
	wantErr(t, err, model.ErrGroupNotFound)
}

func TestGroupGetShowsMembersNoInvite(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	d := env.create(t, env.user(t, "rina"), 5, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	env.join(t, budiID, d.Group.InviteCode)

	// Act
	got, err := env.groups.Get(context.Background(), d.Group.ID, budiID)

	// Assert
	if err != nil || got.Me.Role != model.MemberRoleMember || got.Invite != nil || got.FilledSlots != 2 {
		t.Errorf("Get: %v, detail %+v", err, got)
	}
}

func TestGroupUpdateLogsOnlyChangedFields(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	name, amount := "Arisan Kantor", int64(150_000)

	// Act
	got, err := env.groups.Update(context.Background(), d.Group.ID, rinaID, repository.GroupChange{Name: &name, Amount: &amount})

	// Assert
	if err != nil || got.Group.Name != name {
		t.Fatalf("Update: %v, group %+v", err, got.Group)
	}
	before, after := env.lastLog(t, d.Group.ID)
	if before != `{"name": "Arisan RT 05"}` || after != `{"name": "Arisan Kantor"}` {
		t.Errorf("logged %s -> %s", before, after)
	}
}

func TestGroupUpdateLockedFieldAfterStart(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	env.activate(t, d.Group.ID)
	amount := int64(200_000)

	// Act
	_, err := env.groups.Update(context.Background(), d.Group.ID, rinaID, repository.GroupChange{Amount: &amount})

	// Assert
	wantErr(t, err, model.ErrGroupNotDraft)
}

func TestGroupUpdateByMemberIsForbidden(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	d := env.create(t, env.user(t, "rina"), 5, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	env.join(t, budiID, d.Group.InviteCode)
	name := "Punya Budi"

	// Act
	_, err := env.groups.Update(context.Background(), d.Group.ID, budiID, repository.GroupChange{Name: &name})

	// Assert
	wantErr(t, err, model.ErrForbiddenRole)
}

func TestGroupShrinkMovesMembersDown(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 6, model.DrawMethodRandom)
	gid := d.Group.ID
	a := env.guest(t, gid, rinaID, "Ani", nil)  // slot 2
	b := env.guest(t, gid, rinaID, "Bayu", nil) // slot 3
	env.guest(t, gid, rinaID, "Citra", nil)     // slot 4
	env.guest(t, gid, rinaID, "Dodi", nil)      // slot 5
	for _, m := range []Member{a, b} {
		if err := env.members.Remove(context.Background(), gid, rinaID, m.Member.ID); err != nil {
			t.Fatalf("Remove: %v", err)
		}
	}
	slots := int16(3)

	// Act
	got, err := env.groups.Update(context.Background(), gid, rinaID, repository.GroupChange{TotalSlots: &slots})

	// Assert
	if err != nil || got.Group.TotalSlots != 3 || got.FilledSlots != 3 {
		t.Fatalf("Update: %v, group %+v filled %d", err, got.Group, got.FilledSlots)
	}
	members, err := env.members.List(context.Background(), gid, rinaID, false)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if nos := slotNos(members); nos["Citra"] != 2 || nos["Dodi"] != 3 || len(nos) != 3 {
		t.Errorf("slots %v, want Citra on 2 and Dodi on 3", nos)
	}
}

func TestGroupShrinkBelowMemberCount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	env.guest(t, d.Group.ID, rinaID, "Ani", nil)
	env.guest(t, d.Group.ID, rinaID, "Bayu", nil)
	slots := int16(2)

	// Act
	_, err := env.groups.Update(context.Background(), d.Group.ID, rinaID, repository.GroupChange{TotalSlots: &slots})

	// Assert
	var verr *model.Error
	if !errors.As(err, &verr) || verr.Code != "validation_error" || verr.Fields[0].Field != "total_slots" {
		t.Errorf("err %v, want validation_error on total_slots", err)
	}
}

func TestGroupGrowAddsSlots(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 3, model.DrawMethodRandom)
	slots := int16(5)

	// Act
	_, err := env.groups.Update(context.Background(), d.Group.ID, rinaID, repository.GroupChange{TotalSlots: &slots})

	// Assert
	got, lerr := env.groups.groups.ListSlots(context.Background(), d.Group.ID)
	if err != nil || lerr != nil || len(got) != 5 || got[4].SlotNo != 5 {
		t.Errorf("Update: %v; slots %v, %v", err, got, lerr)
	}
}

func TestGroupSetPaymentInfo(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)

	// Act
	got, err := env.groups.SetPaymentInfo(context.Background(), d.Group.ID, rinaID, " BCA ", "1234567890", "Rina Susanti")

	// Assert
	g := got.Group
	if err != nil || *g.BankName != "BCA" || *g.BankAccountNumber != "1234567890" || *g.BankAccountHolder != "Rina Susanti" {
		t.Fatalf("SetPaymentInfo: %v, group %+v", err, g)
	}
	if acts := env.actions(t, d.Group.ID); acts[len(acts)-1] != "group.payment_info_updated" {
		t.Errorf("activity %v", acts)
	}
}

func TestGroupSetPaymentInfoOrganizerOnly(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	m := env.join(t, budiID, d.Group.InviteCode)
	if err := env.groups.members.SetRole(context.Background(), m.Member.ID, model.MemberRoleCoOrganizer); err != nil {
		t.Fatalf("SetRole: %v", err)
	}

	// Act
	_, err := env.groups.SetPaymentInfo(context.Background(), d.Group.ID, budiID, "BCA", "1234567890", "Budi")

	// Assert
	wantErr(t, err, model.ErrForbiddenRole)
}

// qrisImage renders a valid QRIS payload for merchant as a QR code PNG.
func qrisImage(t *testing.T, merchant string) []byte {
	t.Helper()
	field := func(tag, v string) string { return fmt.Sprintf("%s%02d%s", tag, len(v), v) }
	body := field("00", "01") + field("01", "11") + field("52", "5812") + field("53", "360") +
		field("58", "ID") + field("59", merchant) + field("60", "JAKARTA") + "6304"
	payload := body + fmt.Sprintf("%04X", qris.CRC16(body))
	m, err := qrcode.NewQRCodeWriter().Encode(payload, gozxing.BarcodeFormat_QR_CODE, 300, 300, nil)
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, m); err != nil {
		t.Fatalf("png.Encode: %v", err)
	}
	return buf.Bytes()
}

func TestGroupUploadQRISReplacesImage(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	first, err := env.groups.UploadQRIS(context.Background(), d.Group.ID, rinaID, qrisImage(t, "WARUNG LAMA"))
	if err != nil {
		t.Fatalf("UploadQRIS: %v", err)
	}

	// Act
	got, err := env.groups.UploadQRIS(context.Background(), d.Group.ID, rinaID, qrisImage(t, "WARUNG BU RINA"))

	// Assert
	if err != nil || got.QRISMerchantName == nil || *got.QRISMerchantName != "WARUNG BU RINA" || got.QRISImageURL == nil {
		t.Fatalf("UploadQRIS: %v, detail %+v", err, got)
	}
	keys := env.store.keys()
	if len(keys) != 1 || keys[0] != *got.Group.QRISImageKey || keys[0] == *first.Group.QRISImageKey || !strings.HasSuffix(keys[0], ".png") {
		t.Errorf("stored %v, want only %s", keys, *got.Group.QRISImageKey)
	}
}

func TestGroupUploadQRISRejectsImageWithoutCode(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)

	// Act
	_, err := env.groups.UploadQRIS(context.Background(), d.Group.ID, rinaID, testJPEG(t, 64, 64))

	// Assert
	var verr *model.Error
	if !errors.As(err, &verr) || verr.Code != "validation_error" || verr.Fields[0].Field != "file" || verr.Fields[0].Code != model.FieldInvalidQRIS {
		t.Errorf("err %v, want invalid_qris on file", err)
	}
	if keys := env.store.keys(); len(keys) != 0 {
		t.Errorf("stored %v", keys)
	}
}

func TestGroupDeleteQRIS(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	if _, err := env.groups.UploadQRIS(context.Background(), d.Group.ID, rinaID, qrisImage(t, "WARUNG")); err != nil {
		t.Fatalf("UploadQRIS: %v", err)
	}

	// Act
	err := env.groups.DeleteQRIS(context.Background(), d.Group.ID, rinaID)

	// Assert
	got, gerr := env.groups.Get(context.Background(), d.Group.ID, rinaID)
	if err != nil || gerr != nil || got.Group.HasQRIS() || len(env.store.keys()) != 0 {
		t.Errorf("DeleteQRIS: %v; group %+v, stored %v", err, got.Group, env.store.keys())
	}
}

func TestGroupSetFixedOrder(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 3, model.DrawMethodFixedOrder)
	slots, err := env.groups.groups.ListSlots(context.Background(), d.Group.ID)
	if err != nil {
		t.Fatalf("ListSlots: %v", err)
	}
	order := []SlotPosition{{slots[0].ID, 3}, {slots[1].ID, 1}, {slots[2].ID, 2}}

	// Act
	members, err := env.groups.SetFixedOrder(context.Background(), d.Group.ID, rinaID, order)

	// Assert
	if err != nil || len(members) != 1 || *members[0].FixedOrderPosition != 3 {
		t.Fatalf("SetFixedOrder: %v, members %+v", err, members)
	}
	if _, after := env.lastLog(t, d.Group.ID); after != `{"fixed_order": [2, 3, 1]}` {
		t.Errorf("logged %s", after)
	}
}

func TestGroupSetFixedOrderInvalid(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 3, model.DrawMethodFixedOrder)
	slots, err := env.groups.groups.ListSlots(context.Background(), d.Group.ID)
	if err != nil {
		t.Fatalf("ListSlots: %v", err)
	}
	tests := []struct {
		name      string
		order     []SlotPosition
		wantField string
	}{
		{"missing slot", []SlotPosition{{slots[0].ID, 1}, {slots[1].ID, 2}}, "order"},
		{"duplicate slot", []SlotPosition{{slots[0].ID, 1}, {slots[0].ID, 2}, {slots[2].ID, 3}}, "order[1].slot_id"},
		{"duplicate position", []SlotPosition{{slots[0].ID, 1}, {slots[1].ID, 1}, {slots[2].ID, 3}}, "order[1].position"},
		{"position out of range", []SlotPosition{{slots[0].ID, 1}, {slots[1].ID, 2}, {slots[2].ID, 4}}, "order[2].position"},
		{"foreign slot", []SlotPosition{{slots[0].ID, 1}, {slots[1].ID, 2}, {uuid.Must(uuid.NewV7()), 3}}, "order[2].slot_id"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := env.groups.SetFixedOrder(context.Background(), d.Group.ID, rinaID, tt.order)

			// Assert
			var verr *model.Error
			if !errors.As(err, &verr) || verr.Code != "validation_error" || verr.Fields[0].Field != tt.wantField {
				t.Errorf("err %v (%+v), want validation_error on %s", err, verr, tt.wantField)
			}
		})
	}
}

func TestGroupSetFixedOrderOnRandomGroup(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 2, model.DrawMethodRandom)
	slots, err := env.groups.groups.ListSlots(context.Background(), d.Group.ID)
	if err != nil {
		t.Fatalf("ListSlots: %v", err)
	}

	// Act
	_, err = env.groups.SetFixedOrder(context.Background(), d.Group.ID, rinaID, []SlotPosition{{slots[0].ID, 1}, {slots[1].ID, 2}})

	// Assert
	wantErr(t, err, model.ErrValidation)
}

func TestGroupCloseCancelsPendingAndLocksGroup(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	env.join(t, budiID, d.Group.InviteCode)
	req, err := env.leaves.Request(context.Background(), d.Group.ID, budiID, nil)
	if err != nil {
		t.Fatalf("Request: %v", err)
	}

	// Act
	got, err := env.groups.Close(context.Background(), d.Group.ID, rinaID)

	// Assert
	if err != nil || got.Group.Status != model.GroupStatusClosed || got.Group.ClosedAt == nil {
		t.Fatalf("Close: %v, group %+v", err, got.Group)
	}
	reqs, err := env.leaves.List(context.Background(), d.Group.ID, rinaID, nil)
	if err != nil || len(reqs) != 1 || reqs[0].Request.ID != req.Request.ID || reqs[0].Request.Status != model.LeaveRequestStatusCancelled {
		t.Errorf("leave requests %+v, %v", reqs, err)
	}
	name := "Masih jalan"
	_, err = env.groups.Update(context.Background(), d.Group.ID, rinaID, repository.GroupChange{Name: &name})
	wantErr(t, err, model.ErrGroupNotActive)
}

func TestGroupResetInvite(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 5, model.DrawMethodRandom)

	// Act
	inv, err := env.groups.ResetInvite(context.Background(), d.Group.ID, rinaID)

	// Assert
	if err != nil || inv.Code == d.Group.InviteCode || len(inv.Code) != 8 {
		t.Fatalf("ResetInvite: %v, %+v", err, inv)
	}
	_, err = env.members.PreviewInvite(context.Background(), env.user(t, "budi"), d.Group.InviteCode)
	wantErr(t, err, model.ErrInviteNotFound)
}

func TestListMineFiltersByStatus(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	open := env.create(t, rinaID, 5, model.DrawMethodRandom)
	closed := env.create(t, rinaID, 5, model.DrawMethodRandom)
	if _, err := env.groups.Close(context.Background(), closed.Group.ID, rinaID); err != nil {
		t.Fatalf("Close: %v", err)
	}

	// Act
	active, err := env.groups.ListMine(context.Background(), rinaID, MyGroupsActive)

	// Assert
	if err != nil || len(active) != 1 || active[0].ID != open.Group.ID || active[0].FilledSlots != 1 || active[0].MyRole != model.MemberRoleOrganizer {
		t.Fatalf("ListMine: %v, %+v", err, active)
	}
	finished, err := env.groups.ListMine(context.Background(), rinaID, MyGroupsFinished)
	if err != nil || len(finished) != 1 || finished[0].ID != closed.Group.ID {
		t.Errorf("finished: %v, %+v", err, finished)
	}
}

func TestJoinTakesLowestFreeSlot(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	ani := env.guest(t, d.Group.ID, rinaID, "Ani", nil) // slot 2
	env.guest(t, d.Group.ID, rinaID, "Bayu", nil)       // slot 3
	if err := env.members.Remove(context.Background(), d.Group.ID, rinaID, ani.Member.ID); err != nil {
		t.Fatalf("Remove: %v", err)
	}
	budiID := env.user(t, "budi")

	// Act
	m, err := env.members.Join(context.Background(), budiID, strings.ToLower(d.Group.InviteCode))

	// Assert
	if err != nil || m.SlotNo != 2 || m.Member.UserID == nil || *m.Member.UserID != budiID || m.Member.Role != model.MemberRoleMember {
		t.Fatalf("Join: %v, member %+v", err, m)
	}
	if acts := env.actions(t, d.Group.ID); acts[len(acts)-1] != "member.joined" {
		t.Errorf("activity %v", acts)
	}
}

func TestJoinErrors(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	full := env.create(t, rinaID, 2, model.DrawMethodRandom)
	env.guest(t, full.Group.ID, rinaID, "Ani", nil)
	closed := env.create(t, rinaID, 2, model.DrawMethodRandom)
	if _, err := env.groups.Close(context.Background(), closed.Group.ID, rinaID); err != nil {
		t.Fatalf("Close: %v", err)
	}
	budiID := env.user(t, "budi")
	tests := []struct {
		name   string
		userID uuid.UUID
		code   string
		want   error
	}{
		{"unknown code", budiID, "ZZZZZZZZ", model.ErrInviteNotFound},
		{"full group", budiID, full.Group.InviteCode, model.ErrGroupFull},
		{"closed group", budiID, closed.Group.InviteCode, model.ErrGroupNotActive},
		{"already a member", rinaID, full.Group.InviteCode, model.ErrAlreadyMember},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := env.members.Join(context.Background(), tt.userID, tt.code)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestJoinConcurrentlyGivesDistinctSlots(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 3, model.DrawMethodRandom)
	users := []uuid.UUID{env.user(t, "budi"), env.user(t, "sari"), env.user(t, "joko")}
	errs := make([]error, len(users))
	var wg sync.WaitGroup

	// Act
	for i, u := range users {
		wg.Go(func() { _, errs[i] = env.members.Join(context.Background(), u, d.Group.InviteCode) })
	}
	wg.Wait()

	// Assert
	full := 0
	for _, err := range errs {
		switch {
		case errors.Is(err, model.ErrGroupFull):
			full++
		case err != nil:
			t.Fatalf("Join: %v", err)
		}
	}
	if full != 1 {
		t.Errorf("%d joins got group_full, want 1", full)
	}
	members, err := env.members.List(context.Background(), d.Group.ID, rinaID, false)
	if err != nil || len(members) != 3 || members[0].SlotNo != 1 || members[1].SlotNo != 2 || members[2].SlotNo != 3 {
		t.Errorf("members %+v, %v", members, err)
	}
}

func TestPreviewInvite(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	name := "Rina Susanti"
	if _, err := env.groups.refs.users.UpdateName(context.Background(), rinaID, name); err != nil {
		t.Fatalf("UpdateName: %v", err)
	}
	d := env.create(t, rinaID, 3, model.DrawMethodRandom)

	// Act
	p, err := env.members.PreviewInvite(context.Background(), env.user(t, "budi"), d.Group.InviteCode)

	// Assert
	if err != nil || !p.CanJoin || p.AlreadyMember || p.FilledSlots != 1 || p.Organizer.Name != name {
		t.Errorf("PreviewInvite: %v, %+v", err, p)
	}
}

func TestGuestPhoneHiddenFromMembers(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	phone := "0812-5555-4444"
	g := env.guest(t, d.Group.ID, rinaID, "Ani", &phone)
	budiID := env.user(t, "budi")
	env.join(t, budiID, d.Group.InviteCode)

	// Act
	seen, err := env.members.Get(context.Background(), d.Group.ID, budiID, g.Member.ID)

	// Assert
	if g.Member.GuestPhone == nil || *g.Member.GuestPhone != "+6281255554444" {
		t.Fatalf("organizer sees phone %v, want +6281255554444", g.Member.GuestPhone)
	}
	if err != nil || seen.Member.GuestPhone != nil {
		t.Errorf("member sees phone %v, %v", seen.Member.GuestPhone, err)
	}
}

func TestUpdateGuest(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	phone := "081255554444"
	g := env.guest(t, d.Group.ID, rinaID, "Ani", &phone)
	name := "Ani Wijaya"

	// Act
	got, err := env.members.UpdateGuest(context.Background(), d.Group.ID, rinaID, g.Member.ID, GuestChange{Name: &name, SetPhone: true})

	// Assert
	if err != nil || got.DisplayName() != name || got.Member.GuestPhone != nil {
		t.Fatalf("UpdateGuest: %v, member %+v", err, got.Member)
	}
	if before, after := env.lastLog(t, d.Group.ID); before != `{"name": "Ani", "has_phone": true}` || after != `{"name": "Ani Wijaya", "has_phone": false}` {
		t.Errorf("logged %s -> %s", before, after)
	}
}

func TestUpdateGuestRejectsAccounts(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	name := "Bukan tamu"

	// Act
	_, err := env.members.UpdateGuest(context.Background(), d.Group.ID, rinaID, d.Me.ID, GuestChange{Name: &name})

	// Assert
	wantErr(t, err, model.ErrMemberNotFound)
}

func TestClaimLinkMovesGuestToAccount(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	g := env.guest(t, d.Group.ID, rinaID, "Ani", nil)
	link, err := env.members.CreateClaimLink(context.Background(), d.Group.ID, rinaID, g.Member.ID)
	if err != nil {
		t.Fatalf("CreateClaimLink: %v", err)
	}
	token := strings.TrimPrefix(link.URL, "https://giliran.test/c/")
	sariID := env.user(t, "sari")

	// Act
	m, err := env.members.Claim(context.Background(), sariID, token)

	// Assert
	if err != nil || m.Member.ID != g.Member.ID || m.Member.UserID == nil || *m.Member.UserID != sariID || m.SlotNo != g.SlotNo || m.Member.IsGuest() {
		t.Fatalf("Claim: %v, member %+v", err, m.Member)
	}
	if !link.ExpiresAt.Equal(env.clock.Now().Add(model.ClaimLinkTTL)) {
		t.Errorf("expires %v", link.ExpiresAt)
	}
	_, err = env.members.Claim(context.Background(), env.user(t, "joko"), token)
	wantErr(t, err, model.ErrClaimNotFound)
}

func TestClaimLinkExpires(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	g := env.guest(t, d.Group.ID, rinaID, "Ani", nil)
	link, err := env.members.CreateClaimLink(context.Background(), d.Group.ID, rinaID, g.Member.ID)
	if err != nil {
		t.Fatalf("CreateClaimLink: %v", err)
	}
	sariID := env.user(t, "sari")
	env.clock.Advance(model.ClaimLinkTTL)

	// Act
	_, err = env.members.Claim(context.Background(), sariID, strings.TrimPrefix(link.URL, "https://giliran.test/c/"))

	// Assert
	wantErr(t, err, model.ErrClaimNotFound)
}

func TestClaimByMemberOfGroupIsAlreadyMember(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	g := env.guest(t, d.Group.ID, rinaID, "Ani", nil)
	link, err := env.members.CreateClaimLink(context.Background(), d.Group.ID, rinaID, g.Member.ID)
	if err != nil {
		t.Fatalf("CreateClaimLink: %v", err)
	}

	// Act
	_, err = env.members.Claim(context.Background(), rinaID, strings.TrimPrefix(link.URL, "https://giliran.test/c/"))

	// Assert
	wantErr(t, err, model.ErrAlreadyMember)
}

func TestSignInClaimsGuestsByPhone(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	phone := sari.Phone
	g := env.guest(t, d.Group.ID, rinaID, "Sari", &phone)
	second := env.guest(t, d.Group.ID, rinaID, "Sari lagi", &phone)

	// Act
	sariID := env.user(t, "sari")

	// Assert
	m, err := env.members.Get(context.Background(), d.Group.ID, sariID, g.Member.ID)
	if err != nil || m.Member.UserID == nil || *m.Member.UserID != sariID {
		t.Fatalf("claimed member %+v, %v", m.Member, err)
	}
	other, err := env.members.Get(context.Background(), d.Group.ID, rinaID, second.Member.ID)
	if err != nil || !other.Member.IsGuest() {
		t.Errorf("second guest %+v, %v; want it left as a guest", other.Member, err)
	}
	if acts := env.actions(t, d.Group.ID); acts[len(acts)-1] != "member.guest_claimed" {
		t.Errorf("activity %v", acts)
	}
}

func TestRemoveMember(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	m := env.join(t, budiID, d.Group.InviteCode)

	// Act
	err := env.members.Remove(context.Background(), d.Group.ID, rinaID, m.Member.ID)

	// Assert
	if err != nil {
		t.Fatalf("Remove: %v", err)
	}
	_, err = env.groups.Get(context.Background(), d.Group.ID, budiID)
	wantErr(t, err, model.ErrGroupNotFound)
	all, err := env.members.List(context.Background(), d.Group.ID, rinaID, true)
	if err != nil || len(all) != 2 || all[1].Member.Status != model.MemberStatusRemoved {
		t.Errorf("members %+v, %v", all, err)
	}
}

func TestRemoveMemberErrors(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	budi := env.join(t, budiID, d.Group.InviteCode)
	sari := env.join(t, env.user(t, "sari"), d.Group.InviteCode)
	tests := []struct {
		name     string
		actor    uuid.UUID
		memberID uuid.UUID
		want     error
	}{
		{"organizer", rinaID, d.Me.ID, model.ErrOrganizerCannotLeave},
		{"by a member", budiID, sari.Member.ID, model.ErrForbiddenRole},
		{"unknown member", rinaID, uuid.Must(uuid.NewV7()), model.ErrMemberNotFound},
		{"by a non-member", env.user(t, "joko"), budi.Member.ID, model.ErrGroupNotFound},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			err := env.members.Remove(context.Background(), d.Group.ID, tt.actor, tt.memberID)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestLeaveRequestApproved(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	env.join(t, budiID, d.Group.InviteCode)
	reason := "  Pindah kota  "
	req, err := env.leaves.Request(context.Background(), d.Group.ID, budiID, &reason)
	if err != nil {
		t.Fatalf("Request: %v", err)
	}

	// Act
	got, err := env.leaves.Approve(context.Background(), d.Group.ID, rinaID, req.Request.ID)

	// Assert
	if err != nil || got.Request.Status != model.LeaveRequestStatusApproved || got.ReviewedBy == nil || got.ReviewedBy.ID != rinaID {
		t.Fatalf("Approve: %v, %+v", err, got)
	}
	if *got.Request.Reason != "Pindah kota" || got.Member.Member.Status != model.MemberStatusLeft {
		t.Errorf("request %+v, member %+v", got.Request, got.Member.Member)
	}
	if acts := env.actions(t, d.Group.ID); acts[len(acts)-1] != "member.left" {
		t.Errorf("activity %v", acts)
	}
}

func TestLeaveRequestErrors(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	env.join(t, budiID, d.Group.InviteCode)
	if _, err := env.leaves.Request(context.Background(), d.Group.ID, budiID, nil); err != nil {
		t.Fatalf("Request: %v", err)
	}
	tests := []struct {
		name   string
		userID uuid.UUID
		want   error
	}{
		{"organizer", rinaID, model.ErrOrganizerCannotLeave},
		{"second pending request", budiID, model.ErrPendingRequestExists},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := env.leaves.Request(context.Background(), d.Group.ID, tt.userID, nil)

			// Assert
			wantErr(t, err, tt.want)
		})
	}
}

func TestLeaveRequestRejectedAndListedForOwnerOnly(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID, sariID := env.user(t, "budi"), env.user(t, "sari")
	env.join(t, budiID, d.Group.InviteCode)
	env.join(t, sariID, d.Group.InviteCode)
	req, err := env.leaves.Request(context.Background(), d.Group.ID, budiID, nil)
	if err != nil {
		t.Fatalf("Request: %v", err)
	}
	if _, err := env.leaves.Request(context.Background(), d.Group.ID, sariID, nil); err != nil {
		t.Fatalf("Request: %v", err)
	}
	reason := "Masih ada giliran"
	if _, err := env.leaves.Reject(context.Background(), d.Group.ID, rinaID, req.Request.ID, &reason); err != nil {
		t.Fatalf("Reject: %v", err)
	}

	// Act
	mine, err := env.leaves.List(context.Background(), d.Group.ID, budiID, nil)

	// Assert
	if err != nil || len(mine) != 1 || mine[0].Request.Status != model.LeaveRequestStatusRejected {
		t.Fatalf("List: %v, %+v", err, mine)
	}
	if _, after := env.lastLog(t, d.Group.ID); after != `{"reason": "Masih ada giliran"}` {
		t.Errorf("logged %s", after)
	}
	_, err = env.leaves.Approve(context.Background(), d.Group.ID, rinaID, req.Request.ID)
	wantErr(t, err, model.ErrRequestNotPending)
}

func TestOwnershipTransferAccepted(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	budi := env.join(t, budiID, d.Group.InviteCode)
	if _, err := env.leaves.Request(context.Background(), d.Group.ID, budiID, nil); err != nil {
		t.Fatalf("Request: %v", err)
	}
	offer, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, budi.Member.ID)
	if err != nil {
		t.Fatalf("Offer: %v", err)
	}

	// Act
	got, err := env.ownership.Accept(context.Background(), d.Group.ID, budiID, offer.Transfer.ID)

	// Assert
	if err != nil || got.Transfer.Status != model.OwnershipTransferStatusAccepted || got.From.ID != rinaID || got.To.Member.ID != budi.Member.ID {
		t.Fatalf("Accept: %v, %+v", err, got)
	}
	g, err := env.groups.Get(context.Background(), d.Group.ID, rinaID)
	if err != nil || g.Group.OrganizerID != budiID || g.Me.Role != model.MemberRoleMember {
		t.Errorf("group %+v, rina %+v, %v", g.Group, g.Me, err)
	}
	reqs, err := env.leaves.List(context.Background(), d.Group.ID, budiID, nil)
	if err != nil || reqs[0].Request.Status != model.LeaveRequestStatusCancelled {
		t.Errorf("budi's leave request %+v, %v", reqs, err)
	}
	if acts := env.actions(t, d.Group.ID); acts[len(acts)-1] != "ownership.transferred" {
		t.Errorf("activity %v", acts)
	}
}

func TestOwnershipTransferErrors(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID, sariID := env.user(t, "budi"), env.user(t, "sari")
	budi := env.join(t, budiID, d.Group.InviteCode)
	env.join(t, sariID, d.Group.InviteCode)
	guest := env.guest(t, d.Group.ID, rinaID, "Ani", nil)
	offer, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, budi.Member.ID)
	if err != nil {
		t.Fatalf("Offer: %v", err)
	}

	t.Run("offer to a guest", func(t *testing.T) {
		// Act
		_, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, guest.Member.ID)

		// Assert
		wantErr(t, err, model.ErrValidation)
	})
	t.Run("second pending offer", func(t *testing.T) {
		// Act
		_, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, budi.Member.ID)

		// Assert
		wantErr(t, err, model.ErrPendingRequestExists)
	})
	t.Run("offer by a member", func(t *testing.T) {
		// Act
		_, err := env.ownership.Offer(context.Background(), d.Group.ID, sariID, budi.Member.ID)

		// Assert
		wantErr(t, err, model.ErrForbiddenRole)
	})
	t.Run("accept by someone else", func(t *testing.T) {
		// Act
		_, err := env.ownership.Accept(context.Background(), d.Group.ID, sariID, offer.Transfer.ID)

		// Assert
		wantErr(t, err, model.ErrForbiddenRole)
	})
}

func TestOwnershipTransferExpires(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	budi := env.join(t, budiID, d.Group.InviteCode)
	offer, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, budi.Member.ID)
	if err != nil {
		t.Fatalf("Offer: %v", err)
	}
	env.clock.Advance(model.OwnershipTransferTTL)

	// Act
	_, err = env.ownership.Accept(context.Background(), d.Group.ID, budiID, offer.Transfer.ID)

	// Assert
	wantErr(t, err, model.ErrRequestNotPending)
	var status string
	if err := env.pool.QueryRow(context.Background(), `SELECT status FROM ownership_transfers WHERE id = $1`, offer.Transfer.ID).Scan(&status); err != nil || status != "expired" {
		t.Errorf("status %q, %v; want expired", status, err)
	}
	if _, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, budi.Member.ID); err != nil {
		t.Errorf("new offer after expiry: %v", err)
	}
}

func TestOwnershipTransferDeclined(t *testing.T) {
	// Arrange
	t.Parallel()
	env := newGroupEnv(t)
	rinaID := env.user(t, "rina")
	d := env.create(t, rinaID, 4, model.DrawMethodRandom)
	budiID := env.user(t, "budi")
	budi := env.join(t, budiID, d.Group.InviteCode)
	offer, err := env.ownership.Offer(context.Background(), d.Group.ID, rinaID, budi.Member.ID)
	if err != nil {
		t.Fatalf("Offer: %v", err)
	}

	// Act
	got, err := env.ownership.Decline(context.Background(), d.Group.ID, budiID, offer.Transfer.ID)

	// Assert
	if err != nil || got.Transfer.Status != model.OwnershipTransferStatusDeclined || got.Transfer.RespondedAt == nil {
		t.Fatalf("Decline: %v, %+v", err, got.Transfer)
	}
	g, err := env.groups.Get(context.Background(), d.Group.ID, rinaID)
	if err != nil || g.Group.OrganizerID != rinaID {
		t.Errorf("organizer %v, %v", g.Group.OrganizerID, err)
	}
}
