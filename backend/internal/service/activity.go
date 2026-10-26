package service

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// Entry is one activity log entry to record. A nil Actor is a system entry.
// Before and After hold only the changed fields and are stored as JSON; nil
// stores NULL.
type Entry struct {
	GroupID    uuid.UUID
	Actor      *uuid.UUID
	Action     model.Action
	EntityType model.EntityType
	EntityID   uuid.UUID
	Before     map[string]any
	After      map[string]any
}

// Activity appends to a group's activity log (BR-09).
type Activity struct {
	logs  *repository.ActivityRepository
	clock clock.Clock
}

func NewActivity(logs *repository.ActivityRepository, clk clock.Clock) *Activity {
	return &Activity{logs: logs, clock: clk}
}

// Record writes e. It requires a transaction in ctx, so the entry commits or
// rolls back with the write it describes.
func (a *Activity) Record(ctx context.Context, e Entry) error {
	before, err := marshalChanges(e.Before)
	if err != nil {
		return err
	}
	after, err := marshalChanges(e.After)
	if err != nil {
		return err
	}
	l := model.ActivityLog{
		GroupID:     e.GroupID,
		ActorType:   model.ActorTypeSystem,
		ActorUserID: e.Actor,
		Action:      e.Action,
		EntityType:  e.EntityType,
		EntityID:    &e.EntityID,
		Before:      before,
		After:       after,
	}
	if e.Actor != nil {
		l.ActorType = model.ActorTypeUser
	}
	return a.logs.Insert(ctx, l, a.clock.Now())
}

func marshalChanges(m map[string]any) (json.RawMessage, error) {
	if m == nil {
		return nil, nil
	}
	b, err := json.Marshal(m)
	if err != nil {
		return nil, fmt.Errorf("activity: marshal changes: %w", err)
	}
	return b, nil
}
