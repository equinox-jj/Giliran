package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/repository"
	"github.com/equinox-jj/Giliran/backend/pkg/clock"
)

// IdempotentRequest identifies one idempotent write: the caller's key and
// what the request was. Hash covers the body, so a retry must send the same
// one.
type IdempotentRequest struct {
	UserID uuid.UUID
	Key    string
	Method string
	Path   string
	Hash   string
}

// StoredResponse is the response replayed for a retried key.
type StoredResponse struct {
	Status int
	Body   []byte
}

// IdempotencyService makes payment, payout, draw and reminder writes safe to
// retry (FR-PAY-06).
type IdempotencyService struct {
	tx    *repository.TxManager
	keys  *repository.IdempotencyRepository
	clock clock.Clock
}

func NewIdempotencyService(tx *repository.TxManager, keys *repository.IdempotencyRepository, clk clock.Clock) *IdempotencyService {
	return &IdempotencyService{tx: tx, keys: keys, clock: clk}
}

// Run calls fn once per key. It claims the key and runs fn in one
// transaction, so the key commits with fn's write or not at all; services
// that call WithTx inside fn join it. A retry of a completed request gets the
// stored response back with replayed set, and fn is not called. The same key
// with a different request is idempotency_key_reused.
//
// The claim comes first: a concurrent request with the same key waits on it
// and then replays, rather than racing fn and failing on the state the first
// one left behind. An error from fn rolls the claim back, so failures are
// not stored and a retry runs again.
func (s *IdempotencyService) Run(ctx context.Context, req IdempotentRequest, fn func(ctx context.Context) (StoredResponse, error)) (StoredResponse, bool, error) {
	var resp StoredResponse
	var replayed bool
	err := s.tx.WithTx(ctx, func(ctx context.Context) error {
		k := model.IdempotencyKey{
			UserID: req.UserID, Key: req.Key, Method: req.Method, Path: req.Path, RequestHash: req.Hash,
		}
		now := s.clock.Now()
		claimed, err := s.keys.Claim(ctx, k, now)
		if err != nil {
			return err
		}
		if !claimed {
			stored, err := s.keys.Get(ctx, req.UserID, req.Key)
			if err != nil {
				return err
			}
			if !stored.IsExpired(now) {
				if stored.Method != req.Method || stored.Path != req.Path || !stored.MatchesRequest(req.Hash) {
					return model.ErrIdempotencyKeyReused
				}
				resp, replayed = StoredResponse{Status: int(stored.ResponseStatus), Body: stored.ResponseBody}, true
				return nil
			}
			// Expired keys wait for the cleanup job; this one is free again.
			if err := s.keys.Delete(ctx, req.UserID, req.Key); err != nil {
				return err
			}
			if claimed, err = s.keys.Claim(ctx, k, now); err != nil {
				return err
			}
			if !claimed {
				return errors.New("idempotency: key claimed again after delete")
			}
		}
		if resp, err = fn(ctx); err != nil {
			return err
		}
		if resp.Status < 100 || resp.Status > 599 {
			return fmt.Errorf("idempotency: response status %d", resp.Status)
		}
		var body []byte
		if len(resp.Body) > 0 {
			body = resp.Body
		}
		return s.keys.SaveResponse(ctx, req.UserID, req.Key, int16(resp.Status), body)
	})
	if err != nil {
		return StoredResponse{}, false, err
	}
	return resp, replayed, nil
}
