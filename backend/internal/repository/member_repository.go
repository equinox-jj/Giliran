package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// MemberRepository reads and writes group members and guests.
type MemberRepository struct {
	tx *TxManager
}

func NewMemberRepository(tx *TxManager) *MemberRepository {
	return &MemberRepository{tx: tx}
}

// GetMembership returns userID's active membership in groupID, or
// ErrNotFound when they are not an active member.
func (r *MemberRepository) GetMembership(ctx context.Context, groupID, userID uuid.UUID) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).GetMembership(ctx, sqlc.GetMembershipParams{GroupID: groupID, UserID: &userID})
	return toGroupMember(row), mapErr(err)
}

// GetForUpdate loads and row-locks a member of groupID. Call it inside WithTx.
func (r *MemberRepository) GetForUpdate(ctx context.Context, groupID, id uuid.UUID) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).GetMemberForUpdate(ctx, sqlc.GetMemberForUpdateParams{ID: id, GroupID: groupID})
	return toGroupMember(row), mapErr(err)
}

// Create inserts m; now becomes its joined_at. A user already active in the
// group, or a second organizer, is ErrDuplicate.
func (r *MemberRepository) Create(ctx context.Context, m model.GroupMember, now time.Time) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).CreateMember(ctx, sqlc.CreateMemberParams{
		ID:         m.ID,
		GroupID:    m.GroupID,
		UserID:     m.UserID,
		GuestName:  m.GuestName,
		GuestPhone: m.GuestPhone,
		Role:       string(m.Role),
		Now:        now,
	})
	return toGroupMember(row), mapErr(err)
}

// MemberView is a member with its slot, account name and avatar key, and the
// period its slot won.
type MemberView struct {
	Member             model.GroupMember
	SlotID             uuid.UUID
	SlotNo             int16
	FixedOrderPosition *int16
	UserName           *string
	UserAvatarKey      *string
	WonPeriodNo        *int16
}

// ListViews returns the group's members by slot number; includeInactive adds
// those who left or were removed.
func (r *MemberRepository) ListViews(ctx context.Context, groupID uuid.UUID, includeInactive bool) ([]MemberView, error) {
	rows, err := r.tx.Queries(ctx).ListMemberViews(ctx, sqlc.ListMemberViewsParams{GroupID: groupID, IncludeInactive: includeInactive})
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]MemberView, len(rows))
	for i, row := range rows {
		out[i] = MemberView{
			Member:             toGroupMember(row.GroupMember),
			SlotID:             row.SlotID,
			SlotNo:             row.SlotNo,
			FixedOrderPosition: row.FixedOrderPosition,
			UserName:           row.UserName,
			UserAvatarKey:      row.UserAvatarKey,
			WonPeriodNo:        row.WonPeriodNo,
		}
	}
	return out, nil
}

// GetView returns one member of groupID with its slot.
func (r *MemberRepository) GetView(ctx context.Context, groupID, id uuid.UUID) (MemberView, error) {
	row, err := r.tx.Queries(ctx).GetMemberView(ctx, sqlc.GetMemberViewParams{ID: id, GroupID: groupID})
	if err != nil {
		return MemberView{}, mapErr(err)
	}
	return MemberView{
		Member:             toGroupMember(row.GroupMember),
		SlotID:             row.SlotID,
		SlotNo:             row.SlotNo,
		FixedOrderPosition: row.FixedOrderPosition,
		UserName:           row.UserName,
		UserAvatarKey:      row.UserAvatarKey,
		WonPeriodNo:        row.WonPeriodNo,
	}, nil
}

// CountActive counts the group's active members, guests included.
func (r *MemberRepository) CountActive(ctx context.Context, groupID uuid.UUID) (int, error) {
	n, err := r.tx.Queries(ctx).CountActiveMembers(ctx, groupID)
	return int(n), mapErr(err)
}

// UpdateGuest sets a guest's name and phone. A member with an account is
// ErrNotFound.
func (r *MemberRepository) UpdateGuest(ctx context.Context, id uuid.UUID, name string, phone *string) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).UpdateGuest(ctx, sqlc.UpdateGuestParams{ID: id, GuestName: &name, GuestPhone: phone})
	return toGroupMember(row), mapErr(err)
}

// SetClaimToken stores the hash of a guest's claim token and its expiry.
func (r *MemberRepository) SetClaimToken(ctx context.Context, id uuid.UUID, hash string, expiresAt time.Time) error {
	return mapErr(r.tx.Queries(ctx).SetMemberClaimToken(ctx, sqlc.SetMemberClaimTokenParams{
		ID: id, ClaimTokenHash: &hash, ClaimTokenExpiresAt: &expiresAt,
	}))
}

// GetByClaimTokenHashForUpdate loads and row-locks the guest a claim token
// belongs to. Call it inside WithTx.
func (r *MemberRepository) GetByClaimTokenHashForUpdate(ctx context.Context, hash string) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).GetMemberByClaimTokenHashForUpdate(ctx, &hash)
	return toGroupMember(row), mapErr(err)
}

// ClaimGuest moves the guest row onto userID's account. A user already
// active in the group is ErrDuplicate.
func (r *MemberRepository) ClaimGuest(ctx context.Context, id, userID uuid.UUID) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).ClaimGuest(ctx, sqlc.ClaimGuestParams{ID: id, UserID: &userID})
	return toGroupMember(row), mapErr(err)
}

// ListClaimableGuestsByPhone row-locks and returns the active guests with
// this phone in running groups userID is not in yet. Call it inside WithTx.
func (r *MemberRepository) ListClaimableGuestsByPhone(ctx context.Context, phone string, userID uuid.UUID) ([]model.GroupMember, error) {
	rows, err := r.tx.Queries(ctx).ListClaimableGuestsByPhone(ctx, sqlc.ListClaimableGuestsByPhoneParams{Phone: &phone, UserID: &userID})
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]model.GroupMember, len(rows))
	for i, row := range rows {
		out[i] = toGroupMember(row)
	}
	return out, nil
}

// Deactivate marks the member left or removed at now. Their slot link stays
// for history, and the slot counts as free again.
func (r *MemberRepository) Deactivate(ctx context.Context, id uuid.UUID, status model.MemberStatus, now time.Time) (model.GroupMember, error) {
	row, err := r.tx.Queries(ctx).SetMemberStatus(ctx, sqlc.SetMemberStatusParams{ID: id, Status: string(status), LeftAt: &now})
	return toGroupMember(row), mapErr(err)
}

// SetRole changes the member's role.
func (r *MemberRepository) SetRole(ctx context.Context, id uuid.UUID, role model.MemberRole) error {
	return mapErr(r.tx.Queries(ctx).SetMemberRole(ctx, sqlc.SetMemberRoleParams{ID: id, Role: string(role)}))
}

// HasWon reports whether the member's slot has won a period.
func (r *MemberRepository) HasWon(ctx context.Context, id uuid.UUID) (bool, error) {
	ok, err := r.tx.Queries(ctx).MemberHasWon(ctx, id)
	return ok, mapErr(err)
}

// HasOutstandingObligations reports whether the member has won and still
// owes a payment in some period of the group.
func (r *MemberRepository) HasOutstandingObligations(ctx context.Context, groupID, id uuid.UUID) (bool, error) {
	ok, err := r.tx.Queries(ctx).MemberHasOutstandingObligations(ctx, sqlc.MemberHasOutstandingObligationsParams{
		MemberID: id, GroupID: groupID,
	})
	return ok, mapErr(err)
}

// HasPaymentsInOpenPeriods reports whether the member has a payment past
// unpaid in an open period.
func (r *MemberRepository) HasPaymentsInOpenPeriods(ctx context.Context, id uuid.UUID) (bool, error) {
	ok, err := r.tx.Queries(ctx).MemberHasPaymentsInOpenPeriods(ctx, id)
	return ok, mapErr(err)
}

func toGroupMember(row sqlc.GroupMember) model.GroupMember {
	return model.GroupMember{
		ID:                  row.ID,
		GroupID:             row.GroupID,
		UserID:              row.UserID,
		GuestName:           row.GuestName,
		GuestPhone:          row.GuestPhone,
		Role:                model.MemberRole(row.Role),
		Status:              model.MemberStatus(row.Status),
		ClaimTokenHash:      row.ClaimTokenHash,
		ClaimTokenExpiresAt: row.ClaimTokenExpiresAt,
		JoinedAt:            row.JoinedAt,
		LeftAt:              row.LeftAt,
		CreatedAt:           row.CreatedAt,
		UpdatedAt:           row.UpdatedAt,
	}
}
