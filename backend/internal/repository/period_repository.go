package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository/sqlc"
)

// PeriodRepository reads and writes a group's periods and their sealed draw
// seeds.
type PeriodRepository struct {
	tx *TxManager
}

func NewPeriodRepository(tx *TxManager) *PeriodRepository {
	return &PeriodRepository{tx: tx}
}

// NewPeriod is one period to create.
type NewPeriod struct {
	PeriodNo int16
	DueDate  time.Time
	DrawDate time.Time
}

// CreateAll inserts periods for groupID, all upcoming and drawn with
// algorithm.
func (r *PeriodRepository) CreateAll(ctx context.Context, groupID uuid.UUID, algorithm string, periods []NewPeriod, now time.Time) error {
	arg := sqlc.CreatePeriodsParams{GroupID: groupID, DrawAlgorithm: algorithm, Now: now}
	for _, p := range periods {
		arg.Ids = append(arg.Ids, uuid.Must(uuid.NewV7()))
		arg.PeriodNos = append(arg.PeriodNos, p.PeriodNo)
		arg.DueDates = append(arg.DueDates, p.DueDate)
		arg.DrawDates = append(arg.DrawDates, p.DrawDate)
	}
	return mapErr(r.tx.Queries(ctx).CreatePeriods(ctx, arg))
}

// Get returns a period of groupID.
func (r *PeriodRepository) Get(ctx context.Context, groupID, id uuid.UUID) (model.Period, error) {
	row, err := r.tx.Queries(ctx).GetPeriod(ctx, sqlc.GetPeriodParams{ID: id, GroupID: groupID})
	return toPeriod(row), mapErr(err)
}

// GetForUpdate loads and row-locks a period of groupID. Call it inside
// WithTx.
func (r *PeriodRepository) GetForUpdate(ctx context.Context, groupID, id uuid.UUID) (model.Period, error) {
	row, err := r.tx.Queries(ctx).GetPeriodForUpdate(ctx, sqlc.GetPeriodForUpdateParams{ID: id, GroupID: groupID})
	return toPeriod(row), mapErr(err)
}

// GetByNo returns period periodNo of groupID.
func (r *PeriodRepository) GetByNo(ctx context.Context, groupID uuid.UUID, periodNo int16) (model.Period, error) {
	row, err := r.tx.Queries(ctx).GetPeriodByNo(ctx, sqlc.GetPeriodByNoParams{GroupID: groupID, PeriodNo: periodNo})
	return toPeriod(row), mapErr(err)
}

// Open moves an upcoming period to open and publishes seedHash (nil for
// fixed-order groups). A period that is not upcoming is ErrNotFound.
func (r *PeriodRepository) Open(ctx context.Context, id uuid.UUID, seedHash *string) (model.Period, error) {
	row, err := r.tx.Queries(ctx).OpenPeriod(ctx, sqlc.OpenPeriodParams{ID: id, SeedHash: seedHash})
	return toPeriod(row), mapErr(err)
}

// SealSeed stores the seed behind a period's published hash until the draw
// reveals it. A period has one seed; a second is ErrDuplicate.
func (r *PeriodRepository) SealSeed(ctx context.Context, periodID uuid.UUID, seedHex string, now time.Time) error {
	return mapErr(r.tx.Queries(ctx).CreatePeriodSeed(ctx, sqlc.CreatePeriodSeedParams{PeriodID: periodID, Seed: seedHex, Now: now}))
}

// GetSeed returns the sealed seed behind a period's hash and when it was
// stored, which is when the hash was published.
func (r *PeriodRepository) GetSeed(ctx context.Context, periodID uuid.UUID) (string, time.Time, error) {
	row, err := r.tx.Queries(ctx).GetPeriodSeed(ctx, periodID)
	return row.Seed, row.CreatedAt, mapErr(err)
}

// DrawResult is what a draw stores on its period.
type DrawResult struct {
	Seed             *string // revealed seed; nil for fixed-order groups
	EligibleSlotIDs  []uuid.UUID
	WinnerSlotID     uuid.UUID
	VerificationCode string
	DrawnBy          uuid.UUID
	DrawnAt          time.Time
}

// RecordDraw stores res on an open period and moves it to drawn. A period
// that is not open is ErrNotFound.
func (r *PeriodRepository) RecordDraw(ctx context.Context, id uuid.UUID, res DrawResult) (model.Period, error) {
	row, err := r.tx.Queries(ctx).RecordDraw(ctx, sqlc.RecordDrawParams{
		ID:               id,
		Seed:             res.Seed,
		EligibleSlotIds:  res.EligibleSlotIDs,
		WinnerSlotID:     &res.WinnerSlotID,
		VerificationCode: &res.VerificationCode,
		DrawnAt:          &res.DrawnAt,
		DrawnBy:          &res.DrawnBy,
	})
	return toPeriod(row), mapErr(err)
}

// Close moves a drawn period to closed. A period that is not drawn is
// ErrNotFound.
func (r *PeriodRepository) Close(ctx context.Context, id uuid.UUID) (model.Period, error) {
	row, err := r.tx.Queries(ctx).ClosePeriod(ctx, id)
	return toPeriod(row), mapErr(err)
}

// VerificationCodeExists reports whether some period already uses code.
func (r *PeriodRepository) VerificationCodeExists(ctx context.Context, code string) (bool, error) {
	ok, err := r.tx.Queries(ctx).VerificationCodeExists(ctx, &code)
	return ok, mapErr(err)
}

// PublicDraw is a drawn period found by its verification code, with its
// group's name and size.
type PublicDraw struct {
	Period              model.Period
	GroupName           string
	TotalPeriods        int16
	SeedHashPublishedAt *time.Time // nil for fixed-order groups
}

// GetByCode returns the drawn period whose verification code is code.
func (r *PeriodRepository) GetByCode(ctx context.Context, code string) (PublicDraw, error) {
	row, err := r.tx.Queries(ctx).GetDrawByCode(ctx, &code)
	if err != nil {
		return PublicDraw{}, mapErr(err)
	}
	return PublicDraw{
		Period:              toPeriod(row.Period),
		GroupName:           row.GroupName,
		TotalPeriods:        row.TotalSlots,
		SeedHashPublishedAt: row.SeedHashPublishedAt,
	}, nil
}

// PeriodView is a period with its winner's slot number and payout state.
type PeriodView struct {
	Period          model.Period
	WinnerSlotNo    *int16
	PayoutRecorded  bool
	PayoutConfirmed bool
}

// ListViews returns the group's periods in order.
func (r *PeriodRepository) ListViews(ctx context.Context, groupID uuid.UUID) ([]PeriodView, error) {
	rows, err := r.tx.Queries(ctx).ListPeriodViews(ctx, groupID)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]PeriodView, len(rows))
	for i, row := range rows {
		out[i] = PeriodView{
			Period:          toPeriod(row.Period),
			WinnerSlotNo:    row.WinnerSlotNo,
			PayoutRecorded:  row.PayoutRecorded,
			PayoutConfirmed: row.PayoutConfirmed,
		}
	}
	return out, nil
}

// GetView returns one period of groupID.
func (r *PeriodRepository) GetView(ctx context.Context, groupID, id uuid.UUID) (PeriodView, error) {
	row, err := r.tx.Queries(ctx).GetPeriodView(ctx, sqlc.GetPeriodViewParams{ID: id, GroupID: groupID})
	if err != nil {
		return PeriodView{}, mapErr(err)
	}
	return PeriodView{
		Period:          toPeriod(row.Period),
		WinnerSlotNo:    row.WinnerSlotNo,
		PayoutRecorded:  row.PayoutRecorded,
		PayoutConfirmed: row.PayoutConfirmed,
	}, nil
}

func toPeriod(row sqlc.Period) model.Period {
	return model.Period{
		ID:               row.ID,
		GroupID:          row.GroupID,
		PeriodNo:         row.PeriodNo,
		DueDate:          row.DueDate,
		DrawDate:         row.DrawDate,
		Status:           model.PeriodStatus(row.Status),
		SeedHash:         row.SeedHash,
		Seed:             row.Seed,
		DrawAlgorithm:    row.DrawAlgorithm,
		EligibleSlotIDs:  row.EligibleSlotIds,
		WinnerSlotID:     row.WinnerSlotID,
		VerificationCode: row.VerificationCode,
		DrawnAt:          row.DrawnAt,
		DrawnBy:          row.DrawnBy,
		CreatedAt:        row.CreatedAt,
		UpdatedAt:        row.UpdatedAt,
	}
}
