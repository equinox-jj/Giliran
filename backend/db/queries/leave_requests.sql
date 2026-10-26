-- name: CreateLeaveRequest :one
INSERT INTO leave_requests (id, group_id, member_id, reason, created_at)
VALUES ($1, $2, $3, $4, sqlc.arg(now))
RETURNING *;

-- name: GetLeaveRequestForUpdate :one
SELECT * FROM leave_requests
WHERE id = $1 AND group_id = $2
FOR UPDATE;

-- name: ListLeaveRequests :many
-- Newest first. A NULL member_id or status matches every row.
SELECT * FROM leave_requests
WHERE group_id = sqlc.arg(group_id)
  AND (sqlc.narg(member_id)::uuid IS NULL OR member_id = sqlc.narg(member_id))
  AND (sqlc.narg(status)::text IS NULL OR status = sqlc.narg(status))
ORDER BY created_at DESC, id DESC;

-- name: ReviewLeaveRequest :one
UPDATE leave_requests
SET status = $2, reviewed_by = $3, reviewed_at = $4
WHERE id = $1
RETURNING *;

-- name: CancelPendingLeaveRequests :exec
-- A NULL member_id cancels every pending request in the group.
UPDATE leave_requests
SET status = 'cancelled'
WHERE group_id = sqlc.arg(group_id)
  AND (sqlc.narg(member_id)::uuid IS NULL OR member_id = sqlc.narg(member_id))
  AND status = 'pending';
