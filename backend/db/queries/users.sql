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
