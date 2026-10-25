-- name: CreateSession :one
INSERT INTO sessions (
    id, user_id, family_id, refresh_token_hash,
    device_name, device_platform, fcm_token, last_active_at, expires_at, created_at
) VALUES (
    $1, $2, $3, $4,
    $5, $6, $7, sqlc.arg(now), $8, sqlc.arg(now)
)
RETURNING *;

-- name: GetSessionByRefreshTokenHashForUpdate :one
-- Locks the row so two refreshes of one token serialize.
SELECT * FROM sessions
WHERE refresh_token_hash = $1
FOR UPDATE;

-- name: RotateSession :exec
UPDATE sessions
SET revoked_at = sqlc.arg(now)::timestamptz, revoked_reason = 'rotated', replaced_by_id = sqlc.arg(replaced_by_id)::uuid
WHERE id = sqlc.arg(id) AND revoked_at IS NULL;

-- name: RevokeSessionFamily :execrows
UPDATE sessions
SET revoked_at = sqlc.arg(now)::timestamptz, revoked_reason = sqlc.arg(reason)::text
WHERE family_id = sqlc.arg(family_id) AND revoked_at IS NULL;

-- name: RevokeUserSession :execrows
UPDATE sessions
SET revoked_at = sqlc.arg(now)::timestamptz, revoked_reason = sqlc.arg(reason)::text
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id) AND revoked_at IS NULL;
