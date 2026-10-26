-- name: ClaimIdempotencyKey :execrows
-- Claims the key for a request about to run. response_status 0 is a
-- placeholder that only this transaction ever sees; a concurrent claim of the
-- same key waits for it to commit and then claims nothing.
INSERT INTO idempotency_keys (user_id, key, method, path, request_hash, response_status, created_at, expires_at)
VALUES ($1, $2, $3, $4, $5, 0, sqlc.arg(now)::timestamptz, sqlc.arg(expires_at)::timestamptz)
ON CONFLICT (user_id, key) DO NOTHING;

-- name: GetIdempotencyKey :one
SELECT * FROM idempotency_keys
WHERE user_id = $1 AND key = $2;

-- name: SaveIdempotencyResponse :exec
UPDATE idempotency_keys
SET response_status = $3, response_body = $4
WHERE user_id = $1 AND key = $2;

-- name: DeleteIdempotencyKey :exec
DELETE FROM idempotency_keys
WHERE user_id = $1 AND key = $2;

-- name: DeleteExpiredIdempotencyKeys :execrows
DELETE FROM idempotency_keys
WHERE expires_at <= sqlc.arg(now)::timestamptz;
