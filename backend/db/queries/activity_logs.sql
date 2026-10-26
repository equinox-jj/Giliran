-- name: InsertActivityLog :exec
INSERT INTO activity_logs (
    group_id, actor_type, actor_user_id, action, entity_type, entity_id, before, after, created_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, sqlc.arg(now)
);

-- name: GetDrawCounts :one
-- The paid and total payment counts recorded with a period's draw.
SELECT
    (after ->> 'paid_count')::int AS paid_count,
    (after ->> 'total_count')::int AS total_count
FROM activity_logs
WHERE entity_type = 'period' AND entity_id = sqlc.arg(period_id)::uuid AND action = 'draw.completed'
ORDER BY id DESC
LIMIT 1;

-- name: ListActivity :many
-- A page of the group's log, newest first (DB_SCHEME §8). A NULL before_id
-- starts at the newest entry; the caller asks for one row more than it shows
-- to learn whether another page exists.
SELECT * FROM activity_logs
WHERE group_id = sqlc.arg(group_id)
  AND (sqlc.narg(before_id)::bigint IS NULL OR id < sqlc.narg(before_id)::bigint)
ORDER BY id DESC
LIMIT sqlc.arg(row_limit);

-- name: ListPaymentMembers :many
-- The member each payment belongs to, for the activity log's subject.
SELECT id, member_id FROM payments
WHERE id = ANY(sqlc.arg(ids)::uuid[]);

-- name: ListPayoutMembers :many
-- The winner each payout went to, for the activity log's subject.
SELECT id, winner_member_id FROM payouts
WHERE id = ANY(sqlc.arg(ids)::uuid[]);
