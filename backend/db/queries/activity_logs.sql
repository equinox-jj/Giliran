-- name: InsertActivityLog :exec
INSERT INTO activity_logs (
    group_id, actor_type, actor_user_id, action, entity_type, entity_id, before, after, created_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, sqlc.arg(now)
);
