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
