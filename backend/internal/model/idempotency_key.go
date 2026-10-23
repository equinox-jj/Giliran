package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

const (
	// MinIdempotencyKeyLength and MaxIdempotencyKeyLength bound the
	// Idempotency-Key header.
	MinIdempotencyKeyLength = 8
	MaxIdempotencyKeyLength = 100
	// IdempotencyKeyTTL is how long a stored response is replayed.
	IdempotencyKeyTTL = 24 * time.Hour
)

// IdempotencyKey stores the response of a payment, payout, draw or reminder
// write so a retry returns the same result, mirroring the idempotency_keys
// table (DB_SCHEME §3.15).
type IdempotencyKey struct {
	UserID         uuid.UUID       `db:"user_id"`
	Key            string          `db:"key"` // from the Idempotency-Key header
	Method         string          `db:"method"`
	Path           string          `db:"path"`
	RequestHash    string          `db:"request_hash"` // SHA-256 of the body
	ResponseStatus int16           `db:"response_status"`
	ResponseBody   json.RawMessage `db:"response_body"`
	CreatedAt      time.Time       `db:"created_at"`
	ExpiresAt      time.Time       `db:"expires_at"` // cleaned up by a River job
}

// TableName is the PostgreSQL table that stores idempotency keys.
func (IdempotencyKey) TableName() string {
	return "idempotency_keys"
}

// IsExpired reports whether the stored response can no longer be replayed at
// the given time.
func (k *IdempotencyKey) IsExpired(now time.Time) bool {
	return !now.Before(k.ExpiresAt)
}

// MatchesRequest reports whether a retry carries the same body. A mismatch is
// 422 idempotency_key_reused.
func (k *IdempotencyKey) MatchesRequest(requestHash string) bool {
	return k.RequestHash == requestHash
}
