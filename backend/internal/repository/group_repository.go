package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// GroupRepository reads and writes groups and their slots.
type GroupRepository struct {
	tx *TxManager
}

func NewGroupRepository(tx *TxManager) *GroupRepository {
	return &GroupRepository{tx: tx}
}

// Create inserts g; now becomes its created_at. A taken invite code is
// ErrDuplicate and leaves the transaction usable, so the caller can retry
// with another code.
func (r *GroupRepository) Create(ctx context.Context, g model.Group, now time.Time) (model.Group, error) {
	row, err := r.tx.Queries(ctx).CreateGroup(ctx, sqlc.CreateGroupParams{
		ID:                 g.ID,
		OrganizerID:        g.OrganizerID,
		Name:               g.Name,
		Amount:             g.Amount,
		PeriodType:         string(g.PeriodType),
		TotalSlots:         g.TotalSlots,
		DrawMethod:         string(g.DrawMethod),
		StartDate:          g.StartDate,
		ReminderDaysBefore: g.ReminderDaysBefore,
		InviteCode:         g.InviteCode,
		Now:                now,
	})
	if err = mapErr(err); errors.Is(err, ErrNotFound) {
		return model.Group{}, ErrDuplicate
	}
	return toGroup(row), err
}

func (r *GroupRepository) GetByID(ctx context.Context, id uuid.UUID) (model.Group, error) {
	row, err := r.tx.Queries(ctx).GetGroupByID(ctx, id)
	return toGroup(row), mapErr(err)
}

// GetForUpdate loads and row-locks a group. Call it inside WithTx.
func (r *GroupRepository) GetForUpdate(ctx context.Context, id uuid.UUID) (model.Group, error) {
	row, err := r.tx.Queries(ctx).GetGroupForUpdate(ctx, id)
	return toGroup(row), mapErr(err)
}

func (r *GroupRepository) GetByInviteCode(ctx context.Context, code string) (model.Group, error) {
	row, err := r.tx.Queries(ctx).GetGroupByInviteCode(ctx, code)
	return toGroup(row), mapErr(err)
}

// GroupChange lists the settings to change; nil fields keep their value.
type GroupChange struct {
	Name               *string
	ReminderDaysBefore *int16
	Amount             *int64
	PeriodType         *model.PeriodType
	TotalSlots         *int16
	StartDate          *time.Time
	DrawMethod         *model.DrawMethod
}

// Update applies the non-nil fields of c and returns the result.
func (r *GroupRepository) Update(ctx context.Context, id uuid.UUID, c GroupChange) (model.Group, error) {
	arg := sqlc.UpdateGroupSettingsParams{
		ID:                 id,
		Name:               c.Name,
		ReminderDaysBefore: c.ReminderDaysBefore,
		Amount:             c.Amount,
		TotalSlots:         c.TotalSlots,
		StartDate:          c.StartDate,
	}
	if c.PeriodType != nil {
		v := string(*c.PeriodType)
		arg.PeriodType = &v
	}
	if c.DrawMethod != nil {
		v := string(*c.DrawMethod)
		arg.DrawMethod = &v
	}
	row, err := r.tx.Queries(ctx).UpdateGroupSettings(ctx, arg)
	return toGroup(row), mapErr(err)
}

// SetPaymentInfo stores the organizer's bank account.
func (r *GroupRepository) SetPaymentInfo(ctx context.Context, id uuid.UUID, bank, number, holder string) (model.Group, error) {
	row, err := r.tx.Queries(ctx).SetGroupPaymentInfo(ctx, sqlc.SetGroupPaymentInfoParams{
		ID: id, BankName: &bank, BankAccountNumber: &number, BankAccountHolder: &holder,
	})
	return toGroup(row), mapErr(err)
}

// SetQRIS stores the decoded QRIS payload and its image; nils remove it.
func (r *GroupRepository) SetQRIS(ctx context.Context, id uuid.UUID, payload, imageKey *string) (model.Group, error) {
	row, err := r.tx.Queries(ctx).SetGroupQRIS(ctx, sqlc.SetGroupQRISParams{ID: id, QRISPayload: payload, QRISImageKey: imageKey})
	return toGroup(row), mapErr(err)
}

// SetInviteCode replaces the invite code. A code another group has is
// ErrDuplicate and leaves the transaction usable.
func (r *GroupRepository) SetInviteCode(ctx context.Context, id uuid.UUID, code string) (model.Group, error) {
	row, err := r.tx.Queries(ctx).SetGroupInviteCode(ctx, sqlc.SetGroupInviteCodeParams{ID: id, InviteCode: code})
	if err = mapErr(err); errors.Is(err, ErrNotFound) {
		return model.Group{}, ErrDuplicate
	}
	return toGroup(row), err
}

// Close marks the group closed at now.
func (r *GroupRepository) Close(ctx context.Context, id uuid.UUID, now time.Time) (model.Group, error) {
	row, err := r.tx.Queries(ctx).CloseGroup(ctx, sqlc.CloseGroupParams{ID: id, Now: now})
	return toGroup(row), mapErr(err)
}

// Start marks the group active, started at now.
func (r *GroupRepository) Start(ctx context.Context, id uuid.UUID, now time.Time) (model.Group, error) {
	row, err := r.tx.Queries(ctx).StartGroup(ctx, sqlc.StartGroupParams{ID: id, Now: now})
	return toGroup(row), mapErr(err)
}

// Complete marks an active group completed at now. A group that is not
// active is ErrNotFound.
func (r *GroupRepository) Complete(ctx context.Context, id uuid.UUID, now time.Time) (model.Group, error) {
	row, err := r.tx.Queries(ctx).CompleteGroup(ctx, sqlc.CompleteGroupParams{ID: id, Now: now})
	return toGroup(row), mapErr(err)
}

// SetOrganizer points groups.organizer_id at the new organizer.
func (r *GroupRepository) SetOrganizer(ctx context.Context, id, userID uuid.UUID) error {
	return mapErr(r.tx.Queries(ctx).SetGroupOrganizer(ctx, sqlc.SetGroupOrganizerParams{ID: id, OrganizerID: userID}))
}

// CurrentPeriodID returns the open or drawn period, or nil when there is none.
func (r *GroupRepository) CurrentPeriodID(ctx context.Context, groupID uuid.UUID) (*uuid.UUID, error) {
	id, err := r.tx.Queries(ctx).GetCurrentPeriodID(ctx, groupID)
	if err = mapErr(err); errors.Is(err, ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &id, nil
}

// GroupSummary is one group on the user's home screen, with the current
// period's progress. Period fields are nil while no period is open.
type GroupSummary struct {
	ID                 uuid.UUID
	Name               string
	Amount             int64
	PeriodType         model.PeriodType
	Status             model.GroupStatus
	TotalSlots         int16
	CreatedAt          time.Time
	MyRole             model.MemberRole
	FilledSlots        int
	CurrentPeriodID    *uuid.UUID
	CurrentPeriodNo    *int16
	NextDueDate        *time.Time
	NextDrawDate       *time.Time
	MyPaymentStatus    *model.PaymentStatus
	PaidCount          int
	PendingReviewCount int
	IHaveWon           bool
}

// ListMine returns the groups userID is an active member of whose status is
// in statuses, soonest due date first.
func (r *GroupRepository) ListMine(ctx context.Context, userID uuid.UUID, statuses []model.GroupStatus) ([]GroupSummary, error) {
	names := make([]string, len(statuses))
	for i, s := range statuses {
		names[i] = string(s)
	}
	rows, err := r.tx.Queries(ctx).ListMyGroups(ctx, sqlc.ListMyGroupsParams{UserID: &userID, Statuses: names})
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]GroupSummary, len(rows))
	for i, row := range rows {
		s := GroupSummary{
			ID:                 row.ID,
			Name:               row.Name,
			Amount:             row.Amount,
			PeriodType:         model.PeriodType(row.PeriodType),
			Status:             model.GroupStatus(row.Status),
			TotalSlots:         row.TotalSlots,
			CreatedAt:          row.CreatedAt,
			MyRole:             model.MemberRole(row.MyRole),
			FilledSlots:        int(row.FilledSlots),
			CurrentPeriodID:    row.CurrentPeriodID,
			CurrentPeriodNo:    row.CurrentPeriodNo,
			NextDueDate:        row.NextDueDate,
			NextDrawDate:       row.NextDrawDate,
			PaidCount:          int(row.PaidCount),
			PendingReviewCount: int(row.PendingReviewCount),
			IHaveWon:           row.IHaveWon,
		}
		if row.MyPaymentStatus != "" {
			ps := model.PaymentStatus(row.MyPaymentStatus)
			s.MyPaymentStatus = &ps
		}
		out[i] = s
	}
	return out, nil
}

// CreateSlots inserts slots numbered from..to for the group.
func (r *GroupRepository) CreateSlots(ctx context.Context, groupID uuid.UUID, from, to int16, now time.Time) error {
	if to < from {
		return nil
	}
	ids := make([]uuid.UUID, 0, to-from+1)
	nos := make([]int16, 0, to-from+1)
	for n := from; n <= to; n++ {
		ids = append(ids, uuid.Must(uuid.NewV7()))
		nos = append(nos, n)
	}
	return mapErr(r.tx.Queries(ctx).CreateSlots(ctx, sqlc.CreateSlotsParams{Ids: ids, GroupID: groupID, SlotNos: nos, Now: now}))
}

// ListSlots returns the group's slots by slot number.
func (r *GroupRepository) ListSlots(ctx context.Context, groupID uuid.UUID) ([]model.Slot, error) {
	rows, err := r.tx.Queries(ctx).ListSlots(ctx, groupID)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.Slot, len(rows))
	for i, row := range rows {
		out[i] = toSlot(row)
	}
	return out, nil
}

// ListEligibleSlots returns the group's slots that have not won, by slot
// number: the draw's eligible list.
func (r *GroupRepository) ListEligibleSlots(ctx context.Context, groupID uuid.UUID) ([]model.Slot, error) {
	rows, err := r.tx.Queries(ctx).ListEligibleSlots(ctx, groupID)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.Slot, len(rows))
	for i, row := range rows {
		out[i] = toSlot(row)
	}
	return out, nil
}

// LowestFreeSlot returns the lowest slot with no active holder that has not
// won, or ErrNotFound when the group is full. Lock the group first.
func (r *GroupRepository) LowestFreeSlot(ctx context.Context, groupID uuid.UUID) (model.Slot, error) {
	row, err := r.tx.Queries(ctx).LowestFreeSlot(ctx, groupID)
	return toSlot(row), mapErr(err)
}

// CountFilledSlots counts the slots with an active holder.
func (r *GroupRepository) CountFilledSlots(ctx context.Context, groupID uuid.UUID) (int, error) {
	n, err := r.tx.Queries(ctx).CountFilledSlots(ctx, groupID)
	return int(n), mapErr(err)
}

// AssignSlot gives memberID a full share of slotID.
func (r *GroupRepository) AssignSlot(ctx context.Context, slotID, memberID uuid.UUID, now time.Time) error {
	return mapErr(r.tx.Queries(ctx).AssignSlot(ctx, sqlc.AssignSlotParams{SlotID: slotID, MemberID: memberID, Now: now}))
}

// SlotHolder is a member's link to a slot.
type SlotHolder struct {
	SlotID   uuid.UUID
	MemberID uuid.UUID
}

// ListActiveHoldersAbove returns the active members holding a slot numbered
// above slotNo.
func (r *GroupRepository) ListActiveHoldersAbove(ctx context.Context, groupID uuid.UUID, slotNo int16) ([]SlotHolder, error) {
	rows, err := r.tx.Queries(ctx).ListActiveHoldersAbove(ctx, sqlc.ListActiveHoldersAboveParams{GroupID: groupID, SlotNo: slotNo})
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]SlotHolder, len(rows))
	for i, row := range rows {
		out[i] = SlotHolder{SlotID: row.SlotID, MemberID: row.MemberID}
	}
	return out, nil
}

// MoveSlotHolder moves h to the slot toSlotID.
func (r *GroupRepository) MoveSlotHolder(ctx context.Context, h SlotHolder, toSlotID uuid.UUID) error {
	return mapErr(r.tx.Queries(ctx).MoveSlotMember(ctx, sqlc.MoveSlotMemberParams{
		FromSlotID: h.SlotID, MemberID: h.MemberID, ToSlotID: toSlotID,
	}))
}

// DeleteSlotsAbove drops the slots numbered above slotNo with their links.
// Only for draft groups, where nothing else refers to slots yet.
func (r *GroupRepository) DeleteSlotsAbove(ctx context.Context, groupID uuid.UUID, slotNo int16) error {
	return mapErr(r.tx.Queries(ctx).DeleteSlotsAbove(ctx, sqlc.DeleteSlotsAboveParams{GroupID: groupID, SlotNo: slotNo}))
}

// ClearFixedOrder removes every slot's payout position.
func (r *GroupRepository) ClearFixedOrder(ctx context.Context, groupID uuid.UUID) error {
	return mapErr(r.tx.Queries(ctx).ClearFixedOrder(ctx, groupID))
}

// SetFixedOrder sets the payout position of each slot in positions. Clear
// the order first.
func (r *GroupRepository) SetFixedOrder(ctx context.Context, groupID uuid.UUID, positions map[uuid.UUID]int16) error {
	arg := sqlc.SetFixedOrderPositionsParams{GroupID: groupID}
	for slotID, pos := range positions {
		arg.SlotIds = append(arg.SlotIds, slotID)
		arg.Positions = append(arg.Positions, pos)
	}
	return mapErr(r.tx.Queries(ctx).SetFixedOrderPositions(ctx, arg))
}

func toGroup(row sqlc.Group) model.Group {
	return model.Group{
		ID:                 row.ID,
		OrganizerID:        row.OrganizerID,
		Name:               row.Name,
		Amount:             row.Amount,
		PeriodType:         model.PeriodType(row.PeriodType),
		TotalSlots:         row.TotalSlots,
		DrawMethod:         model.DrawMethod(row.DrawMethod),
		StartDate:          row.StartDate,
		ReminderDaysBefore: row.ReminderDaysBefore,
		Status:             model.GroupStatus(row.Status),
		InviteCode:         row.InviteCode,
		BankName:           row.BankName,
		BankAccountNumber:  row.BankAccountNumber,
		BankAccountHolder:  row.BankAccountHolder,
		QRISPayload:        row.QRISPayload,
		QRISImageKey:       row.QRISImageKey,
		StartedAt:          row.StartedAt,
		CompletedAt:        row.CompletedAt,
		ClosedAt:           row.ClosedAt,
		CreatedAt:          row.CreatedAt,
		UpdatedAt:          row.UpdatedAt,
	}
}

func toSlot(row sqlc.Slot) model.Slot {
	return model.Slot{
		ID:                 row.ID,
		GroupID:            row.GroupID,
		SlotNo:             row.SlotNo,
		FixedOrderPosition: row.FixedOrderPosition,
		Label:              row.Label,
		CreatedAt:          row.CreatedAt,
	}
}
