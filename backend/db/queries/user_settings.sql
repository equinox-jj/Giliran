-- name: CreateUserSettings :exec
INSERT INTO user_settings (user_id)
VALUES ($1);

-- name: GetUserSettings :one
SELECT * FROM user_settings
WHERE user_id = $1;

-- name: UpdateUserSettings :one
-- Changes only the columns whose argument is not NULL.
UPDATE user_settings
SET language                 = COALESCE(sqlc.narg(language), language),
    notify_payment_reminders = COALESCE(sqlc.narg(notify_payment_reminders), notify_payment_reminders),
    notify_draw_results      = COALESCE(sqlc.narg(notify_draw_results), notify_draw_results),
    notify_group_activity    = COALESCE(sqlc.narg(notify_group_activity), notify_group_activity)
WHERE user_id = sqlc.arg(user_id)
RETURNING *;
