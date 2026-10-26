package service

import (
	"context"

	"github.com/google/uuid"
	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/jobs"
	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
)

// notifier queues the push notifications that service writes trigger. Call
// it inside WithTx: the push.send jobs join the transaction, so nobody is
// notified of a write that rolled back. The worker checks each user's
// settings when it sends.
type notifier struct {
	jobs    *jobs.Enqueuer
	members *repository.MemberRepository
}

// toUsers queues one push per user in ids.
func (n notifier) toUsers(ctx context.Context, ids []uuid.UUID, kind notify.Kind, p notify.Params, data map[string]string) error {
	pushes := make([]river.InsertManyParams, len(ids))
	for i, id := range ids {
		pushes[i] = jobs.Push(id, kind, p, data)
	}
	return n.jobs.Enqueue(ctx, pushes...)
}

// toMember queues a push to m's account; a guest gets none.
func (n notifier) toMember(ctx context.Context, m model.GroupMember, kind notify.Kind, p notify.Params, data map[string]string) error {
	if m.UserID == nil {
		return nil
	}
	return n.toUsers(ctx, []uuid.UUID{*m.UserID}, kind, p, data)
}

// toGroup queues a push to the accounts of the group's active members, or
// only those with one of roles, leaving out except (the user who acted).
func (n notifier) toGroup(ctx context.Context, groupID uuid.UUID, except *uuid.UUID, kind notify.Kind, p notify.Params, data map[string]string, roles ...model.MemberRole) error {
	ids, err := n.members.ListActiveUserIDs(ctx, groupID, roles...)
	if err != nil {
		return err
	}
	if except != nil {
		kept := ids[:0]
		for _, id := range ids {
			if id != *except {
				kept = append(kept, id)
			}
		}
		ids = kept
	}
	return n.toUsers(ctx, ids, kind, p, data)
}

// pushData is the routing data of a push about a group's period and,
// optionally, a payment or payout.
func pushData(groupID, periodID uuid.UUID, extra ...string) map[string]string {
	d := map[string]string{"group_id": groupID.String(), "period_id": periodID.String()}
	for i := 0; i+1 < len(extra); i += 2 {
		d[extra[i]] = extra[i+1]
	}
	return d
}
