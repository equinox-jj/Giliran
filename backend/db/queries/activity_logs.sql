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
