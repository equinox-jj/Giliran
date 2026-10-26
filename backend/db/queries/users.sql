-- name: CreateUser :one
INSERT INTO users (id, phone, firebase_uid)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetUserByFirebaseUID :one
SELECT * FROM users
WHERE firebase_uid = $1 AND deleted_at IS NULL;

-- name: GetUserByPhone :one
SELECT * FROM users
WHERE phone = $1 AND deleted_at IS NULL;

-- name: SetUserFirebaseUID :one
UPDATE users SET firebase_uid = $2
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: GetUserByIDForUpdate :one
-- Locks the row so concurrent PIN attempts count correctly.
SELECT * FROM users
WHERE id = $1 AND deleted_at IS NULL
FOR UPDATE;

-- name: SetUserPIN :exec
-- Stores a new PIN hash and clears failed attempts and any lock.
UPDATE users
SET pin_hash = $2, pin_failed_count = 0, pin_locked_until = NULL
WHERE id = $1;

-- name: SetUserPINAttempts :exec
UPDATE users
SET pin_failed_count = $2, pin_locked_until = $3
WHERE id = $1;

-- name: UpdateUserName :one
UPDATE users SET name = $2
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: UpdateUserPhone :one
-- Moves the account to a new number and the Firebase account that verified it.
UPDATE users SET phone = $2, firebase_uid = $3
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: SetUserAvatarKey :one
-- NULL removes the avatar.
UPDATE users SET avatar_key = sqlc.narg(avatar_key)
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
RETURNING *;

-- name: AnonymizeUser :execrows
-- Account deletion (DB_SCHEME §10): personal data goes, the row stays so
-- group history and totals keep pointing at "Mantan anggota".
UPDATE users
SET phone = NULL, firebase_uid = NULL, avatar_key = NULL, pin_hash = NULL,
    pin_failed_count = 0, pin_locked_until = NULL,
    name = 'Mantan anggota', deleted_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id) AND deleted_at IS NULL;
