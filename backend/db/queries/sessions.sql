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

-- name: RevokeOtherUserSessions :execrows
-- Signs the user out everywhere except the current session.
UPDATE sessions
SET revoked_at = sqlc.arg(now)::timestamptz, revoked_reason = sqlc.arg(reason)::text
WHERE user_id = sqlc.arg(user_id) AND id <> sqlc.arg(except_id) AND revoked_at IS NULL;

-- name: ListActiveUserSessions :many
-- The user's signed-in devices, the current one first.
SELECT * FROM sessions
WHERE user_id = sqlc.arg(user_id) AND revoked_at IS NULL AND expires_at > sqlc.arg(now)::timestamptz
ORDER BY id = sqlc.arg(current_id)::uuid DESC, last_active_at DESC, created_at DESC;

-- name: SetSessionFCMToken :execrows
UPDATE sessions SET fcm_token = sqlc.arg(fcm_token)::text
WHERE id = sqlc.arg(id) AND user_id = sqlc.arg(user_id) AND revoked_at IS NULL;

-- name: RevokeAllUserSessions :execrows
UPDATE sessions
SET revoked_at = sqlc.arg(now)::timestamptz, revoked_reason = sqlc.arg(reason)::text
WHERE user_id = sqlc.arg(user_id) AND revoked_at IS NULL;

-- name: ListUserPushTokens :many
-- The push tokens of the user's signed-in, unexpired devices.
SELECT DISTINCT fcm_token::text AS fcm_token FROM sessions
WHERE user_id = sqlc.arg(user_id) AND revoked_at IS NULL
  AND expires_at > sqlc.arg(now)::timestamptz AND fcm_token IS NOT NULL
ORDER BY 1;

-- name: ClearPushTokens :execrows
-- Drops tokens FCM reported as no longer registered, on every session.
UPDATE sessions SET fcm_token = NULL
WHERE fcm_token = ANY(sqlc.arg(tokens)::text[]);

-- name: DeleteStaleSessions :execrows
-- Sessions revoked or expired before the cutoff (DB_SCHEME §10).
DELETE FROM sessions
WHERE revoked_at < sqlc.arg(cutoff)::timestamptz OR expires_at < sqlc.arg(cutoff)::timestamptz;
