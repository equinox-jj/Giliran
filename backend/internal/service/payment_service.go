package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/images"
)

// Proof is an uploaded transfer screenshot with a short-lived download URL.
type Proof struct {
	model.PaymentProof
	URL string
}

// PaymentView is a payment as the caller sees it. CurrentProof is set only
// for the payer and organizers (PRD §10 privacy).
type PaymentView struct {
	Payment      model.Payment
	Member       Member
	CurrentProof *Proof
	ReviewedBy   *UserRef
	IsMine       bool
}

// PaymentDetail is a payment with every proof uploaded for it, newest first.
// Proofs is empty for anyone but the payer and organizers.
type PaymentDetail struct {
	PaymentView
	Proofs []Proof
}

// PaymentService runs the payment board, proof uploads and their review
// (features 21–24, BR-07).
type PaymentService struct {
	tx        *repository.TxManager
	periods   *repository.PeriodRepository
	payments  *repository.PaymentRepository
	members   *repository.MemberRepository
	authz     *Authz
	activity  *Activity
	refs      refs
	store     storage.Storage
	clock     clock.Clock
	log       *slog.Logger
	maxUpload int
}

func NewPaymentService(
	tx *repository.TxManager,
	periods *repository.PeriodRepository,
	payments *repository.PaymentRepository,
	members *repository.MemberRepository,
	users *repository.UserRepository,
	authz *Authz,
	activity *Activity,
	store storage.Storage,
	clk clock.Clock,
	log *slog.Logger,
	cfg *config.Config,
) *PaymentService {
	return &PaymentService{
		tx: tx, periods: periods, payments: payments, members: members, authz: authz, activity: activity,
		refs: refs{users: users, store: store}, store: store, clock: clk, log: log, maxUpload: cfg.MinIO.UploadMaxBytes,
	}
}

// Board returns every payment of a period by slot number, with its summary
// (FR-PAY-01). Any member may read it.
func (s *PaymentService) Board(ctx context.Context, groupID, periodID, userID uuid.UUID) ([]PaymentView, repository.PaymentSummary, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return nil, repository.PaymentSummary{}, err
	}
	if _, err := s.periods.Get(ctx, groupID, periodID); errors.Is(err, repository.ErrNotFound) {
		return nil, repository.PaymentSummary{}, model.ErrPeriodNotFound
	} else if err != nil {
		return nil, repository.PaymentSummary{}, err
	}
	rows, err := s.payments.ListByPeriod(ctx, periodID)
	if err != nil {
		return nil, repository.PaymentSummary{}, err
	}
	b, err := s.newBuilder(ctx, groupID, me)
	if err != nil {
		return nil, repository.PaymentSummary{}, err
	}
	out := make([]PaymentView, len(rows))
	for i, r := range rows {
		if out[i], err = b.view(ctx, r); err != nil {
			return nil, repository.PaymentSummary{}, err
		}
	}
	sum, err := s.payments.Summary(ctx, periodID)
	if err != nil {
		return nil, repository.PaymentSummary{}, err
	}
	return out, sum, nil
}

// Get returns one payment with all its proofs.
func (s *PaymentService) Get(ctx context.Context, groupID, paymentID, userID uuid.UUID) (PaymentDetail, error) {
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return PaymentDetail{}, err
	}
	return s.detail(ctx, groupID, paymentID, me)
}

// UploadProof stores a transfer screenshot from the payer and puts the
// payment in review (FR-PAY-02). It is allowed while the payment is unpaid,
// rejected or still pending review, where it replaces the current proof;
// every proof stays in history. The image is re-encoded, which drops its
// metadata.
func (s *PaymentService) UploadProof(ctx context.Context, groupID, paymentID, userID uuid.UUID, data []byte) (PaymentView, error) {
	// Check who may upload first, so nobody else gets an object stored.
	me, err := s.authz.RequireRole(ctx, groupID, userID)
	if err != nil {
		return PaymentView{}, err
	}
	current, err := s.payments.Get(ctx, groupID, paymentID)
	if errors.Is(err, repository.ErrNotFound) {
		return PaymentView{}, model.ErrPaymentNotFound
	}
	if err != nil {
		return PaymentView{}, err
	}
	if current.Payment.MemberID != me.ID {
		return PaymentView{}, model.ErrForbiddenRole.WithDetail("Only the payer can upload a proof.")
	}
	if len(data) > s.maxUpload {
		return PaymentView{}, model.ErrFileTooLarge
	}
	jpg, err := images.Proof(data)
	if errors.Is(err, images.ErrUnsupported) {
		return PaymentView{}, model.ErrUnsupportedMediaType
	}
	if err != nil {
		return PaymentView{}, err
	}
	// Re-encoding rarely grows an image, but the stored proof must fit too.
	n := len(jpg)
	if n > model.MaxProofSizeBytes {
		return PaymentView{}, model.ErrFileTooLarge
	}
	size := int32(n)

	proofID := uuid.Must(uuid.NewV7())
	key := fmt.Sprintf("proofs/%s/%s/%s.jpg", groupID, paymentID, proofID)
	if err := s.store.Put(ctx, key, images.JPEG, bytes.NewReader(jpg), int64(len(jpg))); err != nil {
		return PaymentView{}, err
	}
	err = s.write(ctx, groupID, paymentID, userID, nil, func(ctx context.Context, w paymentWrite) (model.Payment, Entry, error) {
		if w.payment.MemberID != w.me.ID {
			return model.Payment{}, Entry{}, model.ErrForbiddenRole.WithDetail("Only the payer can upload a proof.")
		}
		// A new proof while pending replaces the current one; BR-07 lists
		// only the moves that change the status.
		if w.payment.Status != model.PaymentStatusPendingReview && !w.payment.Status.CanTransitionTo(model.PaymentStatusPendingReview) {
			return model.Payment{}, Entry{}, model.ErrInvalidPaymentState.WithDetail("A %s payment takes no new proof.", w.payment.Status)
		}
		proof, err := s.payments.CreateProof(ctx, model.PaymentProof{
			ID: proofID, PaymentID: paymentID, ObjectKey: key, ContentType: model.ProofContentTypeJPEG,
			SizeBytes: size, UploadedBy: userID,
		}, w.now)
		if err != nil {
			return model.Payment{}, Entry{}, err
		}
		p, err := s.payments.SetProof(ctx, paymentID, proof.ID)
		// TODO(phase 7): enqueue push.send to the organizers.
		return p, Entry{
			Action: model.ActionPaymentProofUploaded,
			Before: map[string]any{"status": w.payment.Status},
			After:  map[string]any{"status": p.Status, "proof_id": proof.ID},
		}, err
	})
	if err != nil {
		deleteOrphan(ctx, s.store, s.log, key)
		return PaymentView{}, err
	}
	return s.viewOf(ctx, groupID, paymentID, me)
}

// Approve accepts the pending proof: pending_review → paid (FR-PAY-03).
// Organizers and co-organizers only.
func (s *PaymentService) Approve(ctx context.Context, groupID, paymentID, userID uuid.UUID) (PaymentView, error) {
	return s.review(ctx, groupID, paymentID, userID, func(ctx context.Context, w paymentWrite) (model.Payment, Entry, error) {
		p, err := s.payments.SetPaid(ctx, paymentID, model.PaymentMethodTransfer, nil, userID, w.now)
		// TODO(phase 7): enqueue push.send to the payer.
		return p, Entry{
			Action: model.ActionPaymentApproved,
			Before: map[string]any{"status": w.payment.Status},
			After:  map[string]any{"status": p.Status},
		}, err
	})
}

// Reject sends the pending proof back with a reason: pending_review →
// rejected (FR-PAY-03). Organizers and co-organizers only.
func (s *PaymentService) Reject(ctx context.Context, groupID, paymentID, userID uuid.UUID, reason string) (PaymentView, error) {
	reason, err := trimmedLength("reason", reason, model.MinRejectReasonLength, model.MaxNoteLength)
	if err != nil {
		return PaymentView{}, err
	}
	return s.review(ctx, groupID, paymentID, userID, func(ctx context.Context, w paymentWrite) (model.Payment, Entry, error) {
		p, err := s.payments.Reject(ctx, paymentID, reason, userID, w.now)
		// TODO(phase 7): enqueue push.send to the payer.
		return p, Entry{
			Action: model.ActionPaymentRejected,
			Before: map[string]any{"status": w.payment.Status},
			After:  map[string]any{"status": p.Status, "reject_reason": reason},
		}, err
	})
}

// review runs approve or reject: both need a pending proof. A payment that
// was already approved or rejected is payment_already_reviewed, so a second
// device approving the same proof gets a clear answer.
func (s *PaymentService) review(ctx context.Context, groupID, paymentID, userID uuid.UUID, fn paymentWriteFunc) (PaymentView, error) {
	var me model.GroupMember
	err := s.write(ctx, groupID, paymentID, userID, managers, func(ctx context.Context, w paymentWrite) (model.Payment, Entry, error) {
		me = w.me
		// BR-04: the seed hash must be public before a payment counts.
		// Opening the period publishes it, so this only guards a bug.
		if w.group.UsesSeed() && !w.period.HasSeedCommitted() {
			return model.Payment{}, Entry{}, fmt.Errorf("payment: period %s has no seed hash", w.period.ID)
		}
		switch w.payment.Status {
		case model.PaymentStatusPendingReview:
		case model.PaymentStatusPaid, model.PaymentStatusRejected:
			return model.Payment{}, Entry{}, model.ErrPaymentAlreadyReviewed.WithDetail("This payment is already %s.", w.payment.Status)
		default:
			return model.Payment{}, Entry{}, model.ErrInvalidPaymentState.WithDetail("A %s payment has no proof to review.", w.payment.Status)
		}
		return fn(ctx, w)
	})
	if err != nil {
		return PaymentView{}, err
	}
	return s.viewOf(ctx, groupID, paymentID, me)
}

// MarkPaid records a payment made in cash, by a guest, or seen elsewhere,
// without a proof (FR-PAY-04). Organizers and co-organizers only. Allowed
// from unpaid and, as the spec says, from rejected: the organizer may settle
// a disputed proof directly, which BR-07's transitions leave out.
func (s *PaymentService) MarkPaid(ctx context.Context, groupID, paymentID, userID uuid.UUID, method model.PaymentMethod, note *string) (PaymentView, error) {
	if note != nil {
		n, err := trimmedLength("note", *note, 0, model.MaxNoteLength)
		if err != nil {
			return PaymentView{}, err
		}
		note = &n
		if n == "" {
			note = nil
		}
	}
	var me model.GroupMember
	err := s.write(ctx, groupID, paymentID, userID, managers, func(ctx context.Context, w paymentWrite) (model.Payment, Entry, error) {
		me = w.me
		if w.payment.Status != model.PaymentStatusUnpaid && w.payment.Status != model.PaymentStatusRejected {
			return model.Payment{}, Entry{}, model.ErrInvalidPaymentState.WithDetail("A %s payment cannot be marked paid.", w.payment.Status)
		}
		p, err := s.payments.SetPaid(ctx, paymentID, method, note, userID, w.now)
		after := map[string]any{"status": p.Status, "method": method}
		if note != nil {
			after["note"] = *note
		}
		// TODO(phase 7): enqueue push.send to the payer.
		return p, Entry{
			Action: model.ActionPaymentMarkedPaid,
			Before: map[string]any{"status": w.payment.Status},
			After:  after,
		}, err
	})
	if err != nil {
		return PaymentView{}, err
	}
	return s.viewOf(ctx, groupID, paymentID, me)
}

// paymentWrite is what a payment change sees inside its transaction.
type paymentWrite struct {
	group   model.Group
	me      model.GroupMember
	period  model.Period
	payment model.Payment
	now     time.Time
}

// paymentWriteFunc changes w.payment and returns the result with the
// activity entry to record; write fills in the entry's group, actor and
// entity.
type paymentWriteFunc func(ctx context.Context, w paymentWrite) (model.Payment, Entry, error)

// write runs fn on a locked payment of a running group whose period is open,
// and records fn's activity entry, in one transaction. roles limits who may
// call it; nil admits every member. The group lock comes first, as in every
// group write, so payment writes never deadlock with each other.
func (s *PaymentService) write(ctx context.Context, groupID, paymentID, userID uuid.UUID, roles []model.MemberRole, fn paymentWriteFunc) error {
	return s.tx.WithTx(ctx, func(ctx context.Context) error {
		g, me, err := s.authz.LockGroup(ctx, groupID, userID, roles...)
		if err != nil {
			return err
		}
		if err := requireRunning(g); err != nil {
			return err
		}
		p, err := s.payments.GetForUpdate(ctx, groupID, paymentID)
		if errors.Is(err, repository.ErrNotFound) {
			return model.ErrPaymentNotFound
		}
		if err != nil {
			return err
		}
		period, err := s.periods.Get(ctx, groupID, p.PeriodID)
		if err != nil {
			return err
		}
		if !period.IsOpen() {
			return model.ErrPeriodNotOpen.WithDetail("Period %d is %s.", period.PeriodNo, period.Status)
		}
		updated, e, err := fn(ctx, paymentWrite{group: g, me: me, period: period, payment: p, now: s.clock.Now()})
		if err != nil {
			return err
		}
		e.GroupID, e.Actor, e.EntityType, e.EntityID = groupID, &userID, model.EntityTypePayment, updated.ID
		return s.activity.Record(ctx, e)
	})
}

func (s *PaymentService) viewOf(ctx context.Context, groupID, paymentID uuid.UUID, me model.GroupMember) (PaymentView, error) {
	d, err := s.detail(ctx, groupID, paymentID, me)
	return d.PaymentView, err
}

func (s *PaymentService) detail(ctx context.Context, groupID, paymentID uuid.UUID, me model.GroupMember) (PaymentDetail, error) {
	r, err := s.payments.Get(ctx, groupID, paymentID)
	if errors.Is(err, repository.ErrNotFound) {
		return PaymentDetail{}, model.ErrPaymentNotFound
	}
	if err != nil {
		return PaymentDetail{}, err
	}
	b, err := s.newBuilder(ctx, groupID, me)
	if err != nil {
		return PaymentDetail{}, err
	}
	v, err := b.view(ctx, r)
	if err != nil {
		return PaymentDetail{}, err
	}
	d := PaymentDetail{PaymentView: v, Proofs: []Proof{}}
	if !b.canSeeProofs(r.Payment) {
		return d, nil
	}
	proofs, err := s.payments.ListProofs(ctx, paymentID)
	if err != nil {
		return PaymentDetail{}, err
	}
	for _, p := range proofs {
		pr, err := b.proof(ctx, p)
		if err != nil {
			return PaymentDetail{}, err
		}
		d.Proofs = append(d.Proofs, pr)
	}
	return d, nil
}

// paymentBuilder turns payment rows into views for one caller, loading the
// group's members once.
type paymentBuilder struct {
	refs      refs
	me        model.GroupMember
	members   map[uuid.UUID]Member
	reviewers map[uuid.UUID]UserRef
}

func (s *PaymentService) newBuilder(ctx context.Context, groupID uuid.UUID, me model.GroupMember) (*paymentBuilder, error) {
	views, err := s.members.ListViews(ctx, groupID, true)
	if err != nil {
		return nil, err
	}
	b := &paymentBuilder{refs: s.refs, me: me, members: make(map[uuid.UUID]Member, len(views)), reviewers: map[uuid.UUID]UserRef{}}
	for _, v := range views {
		m, err := s.refs.member(ctx, v, false)
		if err != nil {
			return nil, err
		}
		b.members[v.Member.ID] = m
	}
	return b, nil
}

// canSeeProofs reports whether the caller may open p's proofs: the payer and
// organizers only.
func (b *paymentBuilder) canSeeProofs(p model.Payment) bool {
	return p.MemberID == b.me.ID || b.me.Role.CanManageGroup()
}

func (b *paymentBuilder) view(ctx context.Context, r repository.PaymentView) (PaymentView, error) {
	v := PaymentView{Payment: r.Payment, Member: b.members[r.Payment.MemberID], IsMine: r.Payment.MemberID == b.me.ID}
	if r.Proof != nil && b.canSeeProofs(r.Payment) {
		pr, err := b.proof(ctx, *r.Proof)
		if err != nil {
			return PaymentView{}, err
		}
		v.CurrentProof = &pr
	}
	if id := r.Payment.ReviewedBy; id != nil {
		u, ok := b.reviewers[*id]
		if !ok {
			var err error
			if u, err = b.refs.user(ctx, *id); err != nil {
				return PaymentView{}, err
			}
			b.reviewers[*id] = u
		}
		v.ReviewedBy = &u
	}
	return v, nil
}

func (b *paymentBuilder) proof(ctx context.Context, p model.PaymentProof) (Proof, error) {
	url, err := b.refs.store.PresignGet(ctx, p.ObjectKey)
	if err != nil {
		return Proof{}, err
	}
	return Proof{PaymentProof: p, URL: url}, nil
}
