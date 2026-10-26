-- name: CreateOwnershipTransfer :one
INSERT INTO ownership_transfers (id, group_id, from_user_id, to_member_id, expires_at, created_at)
VALUES ($1, $2, $3, $4, $5, sqlc.arg(now))
RETURNING *;

-- name: GetOwnershipTransferForUpdate :one
SELECT * FROM ownership_transfers
WHERE id = $1 AND group_id = $2
FOR UPDATE;

-- name: RespondOwnershipTransfer :one
UPDATE ownership_transfers
SET status = $2, responded_at = $3
WHERE id = $1
RETURNING *;

-- name: ExpireOwnershipTransfers :exec
-- Marks the group's pending transfers past their deadline as expired, so a
-- new offer is not blocked by one nobody can accept any more.
UPDATE ownership_transfers
SET status = 'expired'
WHERE group_id = sqlc.arg(group_id) AND status = 'pending' AND expires_at <= sqlc.arg(now);

-- name: CancelPendingOwnershipTransfers :exec
-- A NULL to_member_id cancels the group's pending transfer whoever it targets.
UPDATE ownership_transfers
SET status = 'cancelled'
WHERE group_id = sqlc.arg(group_id)
  AND (sqlc.narg(to_member_id)::uuid IS NULL OR to_member_id = sqlc.narg(to_member_id))
  AND status = 'pending';
