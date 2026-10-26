package jobs

import (
	"context"
	"log/slog"
	"time"

	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/clients/firebase"
	"github.com/equinox-jj/Giliran/backend/internal/clients/storage"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// ExpireTransfersWorker marks ownership transfers past their 7 days expired
// (ownership_transfers.expire). OwnershipService does the same lazily when
// a group's transfer is touched; neither logs activity, since §7 has no
// action for it.
type ExpireTransfersWorker struct {
	river.WorkerDefaults[ExpireTransfersArgs]
	transfers *repository.OwnershipTransferRepository
	clock     clock.Clock
	log       *slog.Logger
}

func NewExpireTransfersWorker(transfers *repository.OwnershipTransferRepository, clk clock.Clock, log *slog.Logger) *ExpireTransfersWorker {
	return &ExpireTransfersWorker{transfers: transfers, clock: clk, log: log}
}

func (w *ExpireTransfersWorker) Work(ctx context.Context, _ *river.Job[ExpireTransfersArgs]) error {
	n, err := w.transfers.ExpireAllOverdue(ctx, w.clock.Now())
	if err != nil {
		return err
	}
	if n > 0 {
		w.log.InfoContext(ctx, "ownership transfers expired", "count", n)
	}
	return nil
}

// objectDeleter is the part of storage.Storage the workers use.
type objectDeleter interface {
	// Delete removes key. A missing key is not an error.
	Delete(ctx context.Context, key string) error
}

// proofPurgeBatch is how many groups the cleanup loads at a time.
const proofPurgeBatch = 100

// CleanupWorker applies DB_SCHEME §10 (cleanup): it deletes expired
// idempotency keys, sessions revoked or expired over
// RETENTION_REVOKED_SESSIONS ago, and the proof images of groups that
// completed or closed over RETENTION_PAYMENT_PROOFS ago.
type CleanupWorker struct {
	river.WorkerDefaults[CleanupArgs]
	idempotency *repository.IdempotencyRepository
	sessions    *repository.SessionRepository
	groups      *repository.GroupRepository
	store       objectDeleter
	clock       clock.Clock
	retention   config.Retention
	log         *slog.Logger
}

func NewCleanupWorker(
	idempotency *repository.IdempotencyRepository,
	sessions *repository.SessionRepository,
	groups *repository.GroupRepository,
	store storage.Storage,
	clk clock.Clock,
	cfg *config.Config,
	log *slog.Logger,
) *CleanupWorker {
	return &CleanupWorker{
		idempotency: idempotency, sessions: sessions, groups: groups, store: store,
		clock: clk, retention: cfg.Retention, log: log,
	}
}

// Work is idempotent: a failed run leaves nothing half done that the next
// run will not finish. A group is marked purged only once all its objects
// are gone.
func (w *CleanupWorker) Work(ctx context.Context, _ *river.Job[CleanupArgs]) error {
	now := w.clock.Now()
	keys, err := w.idempotency.DeleteExpired(ctx, now)
	if err != nil {
		return err
	}
	sessions, err := w.sessions.DeleteStale(ctx, now.Add(-w.retention.RevokedSessions))
	if err != nil {
		return err
	}
	groups, objects := 0, 0
	cutoff := now.Add(-w.retention.PaymentProofs)
	for {
		ids, err := w.groups.ListDueProofPurge(ctx, cutoff, proofPurgeBatch)
		if err != nil {
			return err
		}
		for _, id := range ids {
			proofs, err := w.groups.ListProofKeys(ctx, id)
			if err != nil {
				return err
			}
			for _, key := range proofs {
				if err := w.store.Delete(ctx, key); err != nil {
					return err
				}
			}
			if err := w.groups.MarkProofsPurged(ctx, id, now); err != nil {
				return err
			}
			groups, objects = groups+1, objects+len(proofs)
		}
		if len(ids) < proofPurgeBatch {
			break
		}
	}
	w.log.InfoContext(ctx, "cleanup done",
		"idempotency_keys", keys, "sessions", sessions, "proof_groups", groups, "proof_objects", objects)
	return nil
}

// AccountPurgeWorker deletes a deleted account's avatar object and Firebase
// user (account.purge), so no phone number stays in Firebase Auth. Both
// deletes ignore what is already gone, so a retry is safe.
type AccountPurgeWorker struct {
	river.WorkerDefaults[AccountPurgeArgs]
	store    objectDeleter
	firebase firebase.UserDeleter
}

func NewAccountPurgeWorker(store storage.Storage, fb firebase.UserDeleter) *AccountPurgeWorker {
	return &AccountPurgeWorker{store: store, firebase: fb}
}

func (w *AccountPurgeWorker) Work(ctx context.Context, job *river.Job[AccountPurgeArgs]) error {
	if k := job.Args.AvatarKey; k != nil {
		if err := w.store.Delete(ctx, *k); err != nil {
			return err
		}
	}
	if uid := job.Args.FirebaseUID; uid != nil {
		return w.firebase.DeleteUser(ctx, *uid)
	}
	return nil
}

// Timeout allows for a backlog of proof objects; River's default is a
// minute.
func (w *CleanupWorker) Timeout(*river.Job[CleanupArgs]) time.Duration {
	return 10 * time.Minute
}
