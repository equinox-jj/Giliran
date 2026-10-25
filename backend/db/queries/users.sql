-- name: CreateUser :one
INSERT INTO users (id, phone, firebase_uid)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1 AND deleted_at IS NULL;
