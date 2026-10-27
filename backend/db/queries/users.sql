-- name: CreateUser :one
-- A new account starts with only its verified email; everything else is set later.
INSERT INTO users (id, email, email_verified_at)
VALUES (sqlc.arg(id), sqlc.arg(email)::text, sqlc.arg(verified_at)::timestamptz)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = sqlc.arg(email)::text AND deleted_at IS NULL;

-- name: GetUserByEmailForUpdate :one
-- Locks the row so the PIN check at sign-in counts attempts correctly.
SELECT * FROM users
WHERE email = sqlc.arg(email)::text AND deleted_at IS NULL
FOR UPDATE;

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

-- name: UpdateUserProfile :one
-- A NULL name keeps the current one. The phone changes only when set_phone is
-- true, and a NULL phone then clears it.
UPDATE users
SET name  = COALESCE(sqlc.narg(name), name),
    phone = CASE WHEN sqlc.arg(set_phone)::boolean THEN sqlc.narg(phone) ELSE phone END
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
RETURNING *;

-- name: UpdateUserEmail :one
-- Moves the account to a newly verified address.
UPDATE users SET email = sqlc.arg(email)::text, email_verified_at = sqlc.arg(verified_at)::timestamptz
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
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
SET email = NULL, email_verified_at = NULL, phone = NULL, avatar_key = NULL, pin_hash = NULL,
    pin_failed_count = 0, pin_locked_until = NULL,
    name = 'Mantan anggota', deleted_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id) AND deleted_at IS NULL;
