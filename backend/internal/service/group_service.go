package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/images"
	"github.com/equinox-jj/Giliran/backend/pkg/qris"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

// inviteCodeAttempts bounds the retries when a new invite code is taken.
// With 36^8 codes a single collision is already rare.
const inviteCodeAttempts = 5

// dateLayout formats business dates in activity log entries.
const dateLayout = time.DateOnly

// NewGroup holds the settings of a group to create.
type NewGroup struct {
	Name               string
	Amount             int64
	PeriodType         model.PeriodType
	TotalSlots         int16
	DrawMethod         model.DrawMethod
	StartDate          time.Time
	ReminderDaysBefore int16
}

// Invite is a group's invite code and the link that opens the join screen.
type Invite struct {
	Code string
	URL  string
}

// GroupDetail is a group as the caller sees it.
type GroupDetail struct {
	Group           model.Group
	Organizer       UserRef
	Me              model.GroupMember
	FilledSlots     int
	CurrentPeriodID *uuid.UUID
	// Invite is set for organizers and co-organizers only.
	Invite           *Invite
	QRISImageURL     *string
	QRISMerchantName *string
}

// SlotPosition is one entry of a fixed payout order.
type SlotPosition struct {
	SlotID   uuid.UUID
	Position int16
}

// MyGroupsFilter selects groups on the home screen.
type MyGroupsFilter string

const (
	// MyGroupsActive is draft and active groups.
	MyGroupsActive   MyGroupsFilter = "active"
	MyGroupsFinished MyGroupsFilter = "finished"
	MyGroupsAll      MyGroupsFilter = "all"
)

func (f MyGroupsFilter) statuses() []model.GroupStatus {
	switch f {
	case MyGroupsFinished:
		return []model.GroupStatus{model.GroupStatusCompleted, model.GroupStatusClosed}
	case MyGroupsAll:
		return []model.GroupStatus{model.GroupStatusDraft, model.GroupStatusActive, model.GroupStatusCompleted, model.GroupStatusClosed}
	}
	return []model.GroupStatus{model.GroupStatusDraft, model.GroupStatusActive}
}

// GroupService creates and runs groups: settings, payment info, fixed order,
// invites and closing (features 14–17).
type GroupService struct {
	tx        *repository.TxManager
	groups    *repository.GroupRepository
	members   *repository.MemberRepository
	leaves    *repository.LeaveRequestRepository
	transfers *repository.OwnershipTransferRepository
	authz     *Authz
	activity  *Activity
	refs      refs
	store     storage.Storage
	clock     clock.Clock
	log       *slog.Logger
	loc       *time.Location
	baseURL   string
	maxUpload int
}

func NewGroupService(
	tx *repository.TxManager,
	groups *repository.GroupRepository,
	members *repository.MemberRepository,
	leaves *repository.LeaveRequestRepository,
	transfers *repository.OwnershipTransferRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
	log *slog.Logger,
	cfg *config.Config,
) *GroupService {
	return &GroupService{
		tx: tx, groups: groups, members: members, leaves: leaves, transfers: transfers,
		authz: authz, activity: activity, refs: refs{users: users, store: store}, store: store,
		clock: clk, log: log, loc: cfg.App.Location, baseURL: strings.TrimRight(cfg.App.PublicBaseURL, "/"),
		maxUpload: cfg.MinIO.UploadMaxBytes,
	}
}

// Create makes userID the organizer of a new draft group: slots
// 1..total_slots, the organizer's membership on slot 1, and the
// group.created entry, in one transaction (FR-GRP-01).
func (s *GroupService) Create(ctx context.Context, userID uuid.UUID, ng NewGroup) (GroupDetail, error) {
	name, err := trimmedLength("name", ng.Name, model.MinGroupNameLength, model.MaxGroupNameLength)
	if err != nil {
		return GroupDetail{}, err
	}
	now := s.clock.Now()
	if err := s.checkStartDate(ng.StartDate, now); err != nil {
		return GroupDetail{}, err
	}

	var g model.Group
	var me model.GroupMember
	err = s.tx.WithTx(ctx, func(ctx context.Context) error {
		err := s.withInviteCode(func(code string) error {
			var err error
			g, err = s.groups.Create(ctx, model.Group{
				ID:                 uuid.Must(uuid.NewV7()),
				OrganizerID:        userID,
				Name:               name,
				Amount:             ng.Amount,
				PeriodType:         ng.PeriodType,
				TotalSlots:         ng.TotalSlots,
				DrawMethod:         ng.DrawMethod,
				StartDate:          ng.StartDate,
				ReminderDaysBefore: ng.ReminderDaysBefore,
				InviteCode:         code,
			}, now)
			return err
		})
		if err != nil {
			return err
		}
		if err := s.groups.CreateSlots(ctx, g.ID, 1, g.TotalSlots, now); err != nil {
			return err
		}
		if me, err = addToFreeSlot(ctx, s.groups, s.members, g.ID, model.GroupMember{UserID: &userID, Role: model.MemberRoleOrganizer}, now); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: g.ID, Actor: &userID, Action: model.ActionGroupCreated,
			EntityType: model.EntityTypeGroup, EntityID: g.ID, After: settingsOf(g),
		})
	})
	if err != nil {
		return GroupDetail{}, err
	}
	return s.detail(ctx, g, me)
}

// addToFreeSlot inserts m into groupID on the lowest free slot. Lock the
// group first; a full group is group_full and a user already in it
// already_member.
func addToFreeSlot(ctx context.Context, groups *repository.GroupRepository, members *repository.MemberRepository,
	groupID uuid.UUID, m model.GroupMember, now time.Time,
) (model.GroupMember, error) {
	slot, err := groups.LowestFreeSlot(ctx, groupID)
	if errors.Is(err, repository.ErrNotFound) {
		return model.GroupMember{}, model.ErrGroupFull
	}
	if err != nil {
		return model.GroupMember{}, err
	}
	m.ID = uuid.Must(uuid.NewV7())
	m.GroupID = groupID
	created, err := members.Create(ctx, m, now)
	if errors.Is(err, repository.ErrDuplicate) {
		return model.GroupMember{}, model.ErrAlreadyMember
	}
	if err != nil {
		return model.GroupMember{}, err
	}
	return created, groups.AssignSlot(ctx, slot.ID, created.ID, now)
}

// withInviteCode calls try with fresh invite codes until one is not taken.
func (s *GroupService) withInviteCode(try func(code string) error) error {
	for range inviteCodeAttempts {
		code, err := security.RandomCode(model.InviteCodeLength)
		if err != nil {
			return err
		}
		if err := try(code); !errors.Is(err, repository.ErrDuplicate) {
			return err
		}
	}
	return fmt.Errorf("group: no free invite code after %d attempts", inviteCodeAttempts)
}

// checkStartDate requires a start date of today or later in Asia/Jakarta.
func (s *GroupService) checkStartDate(start, now time.Time) error {
	if start.Before(utils.Today(now, s.loc)) {
		return model.NewValidationError(model.FieldError{
			Field: "start_date", Code: model.FieldMinimumValue, Message: "Must be today or later.",
		})
	}
	return nil
}

// Get returns a group the caller is a member of.
func (s *GroupService) Get(ctx context.Context, groupID, userID uuid.UUID) (GroupDetail, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return GroupDetail{}, err
	}
	g, err := s.groups.GetByID(ctx, groupID)
	if errors.Is(err, repository.ErrNotFound) {
		return GroupDetail{}, model.ErrGroupNotFound
	}
	if err != nil {
		return GroupDetail{}, err
	}
	return s.detail(ctx, g, me)
}

// ListMine returns the caller's groups for the home screen, soonest due date
// first.
func (s *GroupService) ListMine(ctx context.Context, userID uuid.UUID, filter MyGroupsFilter) ([]repository.GroupSummary, error) {
	return s.groups.ListMine(ctx, userID, filter.statuses())
}

// Update changes the group's settings. Name and reminder days change
// anytime; the rest only while the group is a draft (group_not_draft).
// Values equal to the current ones are ignored, and group.updated holds only
// what changed (FR-GRP-04).
func (s *GroupService) Update(ctx context.Context, groupID, userID uuid.UUID, c repository.GroupChange) (GroupDetail, error) {
	if c.Name != nil {
		name, err := trimmedLength("name", *c.Name, model.MinGroupNameLength, model.MaxGroupNameLength)
		if err != nil {
			return GroupDetail{}, err
		}
		c.Name = &name
	}
	now := s.clock.Now()
	var g model.Group
	var me model.GroupMember
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if g, me, err = s.authz.LockGroup(ctx, groupID, userID, managers...); err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		change, before, after := diffSettings(g, c)
		if len(after) == 0 {
			return nil
		}
		if change.locksDraft && !g.IsDraft() {
			return model.ErrGroupNotDraft
		}
		if change.StartDate != nil {
			if err := s.checkStartDate(*change.StartDate, now); err != nil {
				return err
			}
		}
		if change.TotalSlots != nil {
			if err := s.resizeSlots(ctx, g, *change.TotalSlots, now); err != nil {
				return err
			}
		}
		if g, err = s.groups.Update(ctx, groupID, change.GroupChange); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionGroupUpdated,
			EntityType: model.EntityTypeGroup, EntityID: groupID, Before: before, After: after,
		})
	})
	if err != nil {
		return GroupDetail{}, err
	}
	return s.detail(ctx, g, me)
}

// settingsChange is a GroupChange holding only the fields that differ, and
// whether any of them is draft-only.
type settingsChange struct {
	repository.GroupChange
	locksDraft bool
}

// diffSettings keeps the fields of c that differ from g and returns their
// old and new values for the activity log.
func diffSettings(g model.Group, c repository.GroupChange) (settingsChange, map[string]any, map[string]any) {
	var out settingsChange
	before, after := map[string]any{}, map[string]any{}
	if c.Name != nil && *c.Name != g.Name {
		out.Name, before["name"], after["name"] = c.Name, g.Name, *c.Name
	}
	if c.ReminderDaysBefore != nil && *c.ReminderDaysBefore != g.ReminderDaysBefore {
		out.ReminderDaysBefore, before["reminder_days_before"], after["reminder_days_before"] = c.ReminderDaysBefore, g.ReminderDaysBefore, *c.ReminderDaysBefore
	}
	if c.Amount != nil && *c.Amount != g.Amount {
		out.Amount, before["amount"], after["amount"] = c.Amount, g.Amount, *c.Amount
		out.locksDraft = true
	}
	if c.PeriodType != nil && *c.PeriodType != g.PeriodType {
		out.PeriodType, before["period_type"], after["period_type"] = c.PeriodType, g.PeriodType, *c.PeriodType
		out.locksDraft = true
	}
	if c.TotalSlots != nil && *c.TotalSlots != g.TotalSlots {
		out.TotalSlots, before["total_slots"], after["total_slots"] = c.TotalSlots, g.TotalSlots, *c.TotalSlots
		out.locksDraft = true
	}
	if c.StartDate != nil && !c.StartDate.Equal(g.StartDate) {
		out.StartDate, before["start_date"], after["start_date"] = c.StartDate, g.StartDate.Format(dateLayout), c.StartDate.Format(dateLayout)
		out.locksDraft = true
	}
	if c.DrawMethod != nil && *c.DrawMethod != g.DrawMethod {
		out.DrawMethod, before["draw_method"], after["draw_method"] = c.DrawMethod, g.DrawMethod, *c.DrawMethod
		out.locksDraft = true
	}
	return out, before, after
}

// resizeSlots grows or shrinks a draft group's slots to n. Shrinking moves
// members on dropped slots onto free lower ones, and is refused below the
// number of members. The fixed order is cleared, since its positions no
// longer cover the slots.
func (s *GroupService) resizeSlots(ctx context.Context, g model.Group, n int16, now time.Time) error {
	if n > g.TotalSlots {
		if err := s.groups.CreateSlots(ctx, g.ID, g.TotalSlots+1, n, now); err != nil {
			return err
		}
		return s.groups.ClearFixedOrder(ctx, g.ID)
	}
	active, err := s.members.CountActive(ctx, g.ID)
	if err != nil {
		return err
	}
	if int(n) < active {
		return model.NewValidationError(model.FieldError{
			Field: "total_slots", Code: model.FieldMinimumValue,
			Message: fmt.Sprintf("The group has %d members; remove some before going below that.", active),
		})
	}
	holders, err := s.groups.ListActiveHoldersAbove(ctx, g.ID, n)
	if err != nil {
		return err
	}
	// Every member fits: at most n are active, so a free slot at or below n
	// exists for each one above it, and it is lower than any slot above n.
	for _, h := range holders {
		free, err := s.groups.LowestFreeSlot(ctx, g.ID)
		if err != nil {
			return err
		}
		if err := s.groups.MoveSlotHolder(ctx, h, free.ID); err != nil {
			return err
		}
	}
	if err := s.groups.DeleteSlotsAbove(ctx, g.ID, n); err != nil {
		return err
	}
	return s.groups.ClearFixedOrder(ctx, g.ID)
}

// SetPaymentInfo stores the organizer's bank account (FR-GRP-03). Organizer
// only, since the money goes to their account.
func (s *GroupService) SetPaymentInfo(ctx context.Context, groupID, userID uuid.UUID, bank, number, holder string) (GroupDetail, error) {
	bank, holder = strings.TrimSpace(bank), strings.TrimSpace(holder)
	var fields []model.FieldError
	if bank == "" {
		fields = append(fields, model.FieldError{Field: "bank_name", Code: model.FieldRequired, Message: "This field is required."})
	}
	if holder == "" {
		fields = append(fields, model.FieldError{Field: "account_holder", Code: model.FieldRequired, Message: "This field is required."})
	}
	if len(fields) > 0 {
		return GroupDetail{}, model.NewValidationError(fields...)
	}

	var g model.Group
	var me model.GroupMember
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if g, me, err = s.authz.LockGroup(ctx, groupID, userID, organizerOnly...); err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		before := bankInfoOf(g)
		if g, err = s.groups.SetPaymentInfo(ctx, groupID, bank, number, holder); err != nil {
			return err
		}
		after := bankInfoOf(g)
		if maps.Equal(before, after) {
			return nil
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionGroupPaymentInfoUpdated,
			EntityType: model.EntityTypeGroup, EntityID: groupID, Before: before, After: after,
		})
	})
	if err != nil {
		return GroupDetail{}, err
	}
	return s.detail(ctx, g, me)
}

// UploadQRIS reads the QR code in an image, checks it is a valid QRIS
// payload (EMV TLV and CRC-16) and stores the image and payload
// (FR-GRP-03). An image without a valid code is validation_error on file.
func (s *GroupService) UploadQRIS(ctx context.Context, groupID, userID uuid.UUID, data []byte) (GroupDetail, error) {
	// Check the role first, so nobody else gets an object stored.
	if _, err := s.authz.RequireRole(ctx, groupID, userID, organizerOnly...); err != nil {
		return GroupDetail{}, err
	}
	if len(data) > s.maxUpload {
		return GroupDetail{}, model.ErrFileTooLarge
	}
	contentType, err := images.Sniff(data)
	if errors.Is(err, images.ErrUnsupported) {
		return GroupDetail{}, model.ErrUnsupportedMediaType
	}
	if err != nil {
		return GroupDetail{}, err
	}
	payload, err := readQRIS(data)
	if err != nil {
		return GroupDetail{}, err
	}

	key := fmt.Sprintf("qris/%s/%s%s", groupID, uuid.Must(uuid.NewV7()), extensionOf(contentType))
	if err := s.store.Put(ctx, key, contentType, bytes.NewReader(data), int64(len(data))); err != nil {
		return GroupDetail{}, err
	}
	merchant := payload.MerchantName()
	g, me, old, err := s.swapQRIS(ctx, groupID, userID, &payload.Raw, &key, &merchant)
	if err != nil {
		s.deleteObject(ctx, key)
		return GroupDetail{}, err
	}
	if old != nil {
		s.deleteObject(ctx, *old)
	}
	return s.detail(ctx, g, me)
}

// readQRIS decodes and validates the QRIS code in an image.
func readQRIS(data []byte) (qris.Payload, error) {
	invalid := func(msg string) error {
		return model.NewValidationError(model.FieldError{Field: "file", Code: model.FieldInvalidQRIS, Message: msg})
	}
	raw, err := qris.Decode(data)
	if errors.Is(err, qris.ErrNoCode) {
		return qris.Payload{}, invalid("No readable QR code was found in the image.")
	}
	if err != nil {
		return qris.Payload{}, err
	}
	payload, err := qris.Parse(raw)
	if errors.Is(err, qris.ErrInvalid) {
		return qris.Payload{}, invalid("The QR code is not a valid QRIS code.")
	}
	return payload, err
}

func extensionOf(contentType string) string {
	switch contentType {
	case images.PNG:
		return ".png"
	case images.WebP:
		return ".webp"
	}
	return ".jpg"
}

// DeleteQRIS removes the QRIS code. Having none is not an error.
func (s *GroupService) DeleteQRIS(ctx context.Context, groupID, userID uuid.UUID) error {
	_, _, old, err := s.swapQRIS(ctx, groupID, userID, nil, nil, nil)
	if err != nil {
		return err
	}
	if old != nil {
		s.deleteObject(ctx, *old)
	}
	return nil
}

// swapQRIS sets the group's QRIS under the group lock and returns the group,
// the caller's membership and the image key it replaced. merchant is the new
// merchant name for the activity log.
func (s *GroupService) swapQRIS(ctx context.Context, groupID, userID uuid.UUID, payload, key, merchant *string) (model.Group, model.GroupMember, *string, error) {
	var g model.Group
	var me model.GroupMember
	var old *string
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if g, me, err = s.authz.LockGroup(ctx, groupID, userID, organizerOnly...); err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		if payload == nil && !g.HasQRIS() {
			return nil
		}
		old = g.QRISImageKey
		before := map[string]any{"qris_merchant_name": merchantName(g.QRISPayload)}
		if g, err = s.groups.SetQRIS(ctx, groupID, payload, key); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionGroupPaymentInfoUpdated,
			EntityType: model.EntityTypeGroup, EntityID: groupID,
			Before: before, After: map[string]any{"qris_merchant_name": merchant},
		})
	})
	return g, me, old, err
}

// deleteObject removes an object nothing points at any more. A failure only
// leaves an orphan behind, so it is logged rather than returned.
func (s *GroupService) deleteObject(ctx context.Context, key string) {
	if err := s.store.Delete(context.WithoutCancel(ctx), key); err != nil {
		s.log.WarnContext(ctx, "orphaned storage object", "key", key, "error", err)
	}
}

// SetFixedOrder sets the payout order of a draft fixed-order group. Every
// slot must appear exactly once, with positions 1..total_slots (FR-GRP-02).
func (s *GroupService) SetFixedOrder(ctx context.Context, groupID, userID uuid.UUID, order []SlotPosition) ([]Member, error) {
	var me model.GroupMember
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, m, err := s.authz.LockGroup(ctx, groupID, userID, managers...)
		if err != nil {
			return err
		}
		me = m
		if err := requireRunning(g); err != nil {
			return err
		}
		if !g.IsDraft() {
			return model.ErrGroupNotDraft
		}
		if g.DrawMethod != model.DrawMethodFixedOrder {
			return model.NewValidationError(model.FieldError{
				Field: "order", Code: model.FieldInvalidChoice,
				Message: "The group draws at random; set draw_method to fixed_order first.",
			})
		}
		slots, err := s.groups.ListSlots(ctx, groupID)
		if err != nil {
			return err
		}
		positions, err := checkFixedOrder(slots, order)
		if err != nil {
			return err
		}
		if err := s.groups.ClearFixedOrder(ctx, groupID); err != nil {
			return err
		}
		if err := s.groups.SetFixedOrder(ctx, groupID, positions); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionGroupUpdated,
			EntityType: model.EntityTypeGroup, EntityID: groupID,
			Before: map[string]any{"fixed_order": orderOf(slots, nil)},
			After:  map[string]any{"fixed_order": orderOf(slots, positions)},
		})
	})
	if err != nil {
		return nil, err
	}
	views, err := s.members.ListViews(ctx, groupID, false)
	if err != nil {
		return nil, err
	}
	return s.refs.members(ctx, views, me.Role.CanManageGroup())
}

// checkFixedOrder validates order against the group's slots and returns the
// position of each slot.
func checkFixedOrder(slots []model.Slot, order []SlotPosition) (map[uuid.UUID]int16, error) {
	if len(order) != len(slots) {
		return nil, model.NewValidationError(model.FieldError{
			Field: "order", Code: model.FieldInvalidFormat,
			Message: fmt.Sprintf("Give each of the %d slots exactly one position.", len(slots)),
		})
	}
	known := make(map[uuid.UUID]bool, len(slots))
	for _, sl := range slots {
		known[sl.ID] = true
	}
	positions := make(map[uuid.UUID]int16, len(order))
	taken := make(map[int16]bool, len(order))
	var fields []model.FieldError
	for i, o := range order {
		switch {
		case !known[o.SlotID]:
			fields = append(fields, model.FieldError{
				Field: fmt.Sprintf("order[%d].slot_id", i), Code: model.FieldInvalidChoice, Message: "Not a slot of this group.",
			})
		case positions[o.SlotID] != 0:
			fields = append(fields, model.FieldError{
				Field: fmt.Sprintf("order[%d].slot_id", i), Code: model.FieldDuplicate, Message: "This slot already has a position.",
			})
		}
		switch {
		case o.Position < 1 || int(o.Position) > len(slots):
			fields = append(fields, model.FieldError{
				Field: fmt.Sprintf("order[%d].position", i), Code: model.FieldMaximumValue,
				Message: fmt.Sprintf("Must be between 1 and %d.", len(slots)),
			})
		case taken[o.Position]:
			fields = append(fields, model.FieldError{
				Field: fmt.Sprintf("order[%d].position", i), Code: model.FieldDuplicate, Message: "Another slot has this position.",
			})
		}
		positions[o.SlotID] = o.Position
		taken[o.Position] = true
	}
	if len(fields) > 0 {
		return nil, model.NewValidationError(fields...)
	}
	return positions, nil
}

// orderOf lists slot numbers in payout order: from positions when given,
// otherwise from the slots' stored positions.
func orderOf(slots []model.Slot, positions map[uuid.UUID]int16) []int16 {
	byPos := make([]int16, len(slots)+1)
	for _, sl := range slots {
		pos := sl.FixedOrderPosition
		if positions != nil {
			p := positions[sl.ID]
			pos = &p
		}
		if pos != nil && int(*pos) < len(byPos) {
			byPos[*pos] = sl.SlotNo
		}
	}
	out := []int16{}
	for _, no := range byPos[1:] {
		if no != 0 {
			out = append(out, no)
		}
	}
	return out
}

// Close ends the group early; it stays read-only in history (FR-GRP-04).
// Pending leave requests and ownership transfers are cancelled. Closing a
// closed group returns it unchanged.
func (s *GroupService) Close(ctx context.Context, groupID, userID uuid.UUID) (GroupDetail, error) {
	now := s.clock.Now()
	var g model.Group
	var me model.GroupMember
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if g, me, err = s.authz.LockGroup(ctx, groupID, userID, organizerOnly...); err != nil {
			return err
		}
		if g.Status == model.GroupStatusClosed {
			return nil
		}
		if !g.Status.CanTransitionTo(model.GroupStatusClosed) {
			return model.ErrGroupNotActive.WithDetail("A %s group cannot be closed.", g.Status)
		}
		before := g.Status
		if g, err = s.groups.Close(ctx, groupID, now); err != nil {
			return err
		}
		if err := s.leaves.CancelPending(ctx, groupID, nil); err != nil {
			return err
		}
		if err := s.transfers.CancelPending(ctx, groupID, nil); err != nil {
			return err
		}
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionGroupClosed,
			EntityType: model.EntityTypeGroup, EntityID: groupID,
			Before: map[string]any{"status": before}, After: map[string]any{"status": g.Status},
		})
	})
	if err != nil {
		return GroupDetail{}, err
	}
	return s.detail(ctx, g, me)
}

// ResetInvite replaces the invite code, so old links stop working
// (FR-MEM-01).
func (s *GroupService) ResetInvite(ctx context.Context, groupID, userID uuid.UUID) (Invite, error) {
	var g model.Group
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		var err error
		if g, _, err = s.authz.LockGroup(ctx, groupID, userID, managers...); err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		err = s.withInviteCode(func(code string) error {
			var err error
			g, err = s.groups.SetInviteCode(ctx, groupID, code)
			return err
		})
		if err != nil {
			return err
		}
		// The code itself stays out of the log: every member can read the
		// log, but only organizers see the invite.
		return s.activity.Record(ctx, Entry{
			GroupID: groupID, Actor: &userID, Action: model.ActionGroupInviteReset,
			EntityType: model.EntityTypeGroup, EntityID: groupID,
		})
	})
	if err != nil {
		return Invite{}, err
	}
	return s.invite(g.InviteCode), nil
}

func (s *GroupService) invite(code string) Invite {
	return Invite{Code: code, URL: s.baseURL + "/j/" + code}
}

// detail assembles what the caller sees of g.
func (s *GroupService) detail(ctx context.Context, g model.Group, me model.GroupMember) (GroupDetail, error) {
	d := GroupDetail{Group: g, Me: me}
	var err error
	if d.Organizer, err = s.refs.user(ctx, g.OrganizerID); err != nil {
		return GroupDetail{}, err
	}
	if d.FilledSlots, err = s.groups.CountFilledSlots(ctx, g.ID); err != nil {
		return GroupDetail{}, err
	}
	if d.CurrentPeriodID, err = s.groups.CurrentPeriodID(ctx, g.ID); err != nil {
		return GroupDetail{}, err
	}
	if d.QRISImageURL, err = s.refs.presign(ctx, g.QRISImageKey); err != nil {
		return GroupDetail{}, err
	}
	d.QRISMerchantName = merchantName(g.QRISPayload)
	if me.Role.CanManageGroup() {
		inv := s.invite(g.InviteCode)
		d.Invite = &inv
	}
	return d, nil
}

// merchantName reads tag 59 from a stored QRIS payload.
func merchantName(payload *string) *string {
	if payload == nil {
		return nil
	}
	p, err := qris.Parse(*payload)
	if err != nil {
		return nil
	}
	name := p.MerchantName()
	return &name
}

// settingsOf is the group.created entry: the settings the group starts with.
func settingsOf(g model.Group) map[string]any {
	return map[string]any{
		"name":                 g.Name,
		"amount":               g.Amount,
		"period_type":          g.PeriodType,
		"total_slots":          g.TotalSlots,
		"draw_method":          g.DrawMethod,
		"start_date":           g.StartDate.Format(dateLayout),
		"reminder_days_before": g.ReminderDaysBefore,
	}
}

// bankInfoOf is the bank account part of payment info, for the activity log.
// Members can already see it, so logging it reveals nothing new.
func bankInfoOf(g model.Group) map[string]any {
	return map[string]any{
		"bank_name":      valueOf(g.BankName),
		"account_number": valueOf(g.BankAccountNumber),
		"account_holder": valueOf(g.BankAccountHolder),
	}
}

// valueOf is *p, or nil (JSON null) when p is nil.
func valueOf(p *string) any {
	if p == nil {
		return nil
	}
	return *p
}
