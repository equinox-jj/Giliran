-- name: CreateGroup :one
-- A taken invite code inserts nothing and returns no rows, so the caller can
-- retry with another code without aborting its transaction.
INSERT INTO groups (
    id, organizer_id, name, amount, period_type, total_slots, draw_method,
    start_date, reminder_days_before, invite_code, created_at, updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7,
    $8, $9, $10, sqlc.arg(now), sqlc.arg(now)
)
ON CONFLICT (invite_code) DO NOTHING
RETURNING *;

-- name: GetGroupByID :one
SELECT * FROM groups
WHERE id = $1;

-- name: GetGroupForUpdate :one
-- Locks the group so slot assignment, role changes and status changes
-- serialize.
SELECT * FROM groups
WHERE id = $1
FOR UPDATE;

-- name: GetGroupByInviteCode :one
SELECT * FROM groups
WHERE invite_code = $1;

-- name: UpdateGroupSettings :one
-- NULL arguments keep the current value.
UPDATE groups
SET name                 = COALESCE(sqlc.narg(name), name),
    reminder_days_before = COALESCE(sqlc.narg(reminder_days_before), reminder_days_before),
    amount               = COALESCE(sqlc.narg(amount), amount),
    period_type          = COALESCE(sqlc.narg(period_type), period_type),
    total_slots          = COALESCE(sqlc.narg(total_slots), total_slots),
    start_date           = COALESCE(sqlc.narg(start_date), start_date),
    draw_method          = COALESCE(sqlc.narg(draw_method), draw_method)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: SetGroupPaymentInfo :one
UPDATE groups
SET bank_name = $2, bank_account_number = $3, bank_account_holder = $4
WHERE id = $1
RETURNING *;

-- name: SetGroupQRIS :one
-- NULLs remove the QRIS.
UPDATE groups
SET qris_payload = sqlc.narg(qris_payload), qris_image_key = sqlc.narg(qris_image_key)
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: SetGroupInviteCode :one
-- Returns no rows when another group already has the code, so the caller can
-- retry without aborting its transaction.
UPDATE groups
SET invite_code = sqlc.arg(invite_code)
WHERE groups.id = sqlc.arg(id)
  AND NOT EXISTS (SELECT 1 FROM groups other WHERE other.invite_code = sqlc.arg(invite_code))
RETURNING *;

-- name: CloseGroup :one
UPDATE groups
SET status = 'closed', closed_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: SetGroupOrganizer :exec
UPDATE groups
SET organizer_id = $2
WHERE id = $1;

-- name: GetCurrentPeriodID :one
-- The period being collected or waiting for its payout.
SELECT id FROM periods
WHERE group_id = $1 AND status IN ('open', 'drawn')
ORDER BY period_no
LIMIT 1;

-- name: ListMyGroups :many
-- The user's groups with the current period's progress, soonest due date
-- first. Period columns are NULL while no period is open.
SELECT
    g.id,
    g.name,
    g.amount,
    g.period_type,
    g.status,
    g.total_slots,
    g.created_at,
    gm.role AS my_role,
    (SELECT count(*) FROM slots s
     WHERE s.group_id = g.id AND EXISTS (
         SELECT 1 FROM slot_members sm JOIN group_members h ON h.id = sm.member_id
         WHERE sm.slot_id = s.id AND h.status = 'active'))::int AS filled_slots,
    cp.id AS current_period_id,
    cp.period_no AS current_period_no,
    cp.due_date AS next_due_date,
    cp.draw_date AS next_draw_date,
    -- '' when the user has no payment in the current period
    COALESCE((SELECT pay.status FROM payments pay
              WHERE pay.period_id = cp.id AND pay.member_id = gm.id
              LIMIT 1), '')::text AS my_payment_status,
    (SELECT count(*) FROM payments pay WHERE pay.period_id = cp.id AND pay.status = 'paid')::int AS paid_count,
    (SELECT count(*) FROM payments pay WHERE pay.period_id = cp.id AND pay.status = 'pending_review')::int AS pending_review_count,
    EXISTS (
        SELECT 1 FROM periods wp JOIN slot_members sm ON sm.slot_id = wp.winner_slot_id
        WHERE wp.group_id = g.id AND sm.member_id = gm.id) AS i_have_won
FROM group_members gm
JOIN groups g ON g.id = gm.group_id
LEFT JOIN periods cp ON cp.id = (
    SELECT p.id FROM periods p
    WHERE p.group_id = g.id AND p.status IN ('open', 'drawn')
    ORDER BY p.period_no
    LIMIT 1)
WHERE gm.user_id = sqlc.arg(user_id)
  AND gm.status = 'active'
  AND g.status = ANY (sqlc.arg(statuses)::text[])
ORDER BY cp.due_date NULLS LAST, g.created_at DESC;

-- name: StartGroup :one
UPDATE groups
SET status = 'active', started_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: CompleteGroup :one
-- The last period's payout completes the cycle.
UPDATE groups
SET status = 'completed', completed_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id) AND status = 'active'
RETURNING *;

-- name: ListGroupsDueProofPurge :many
-- Completed or closed groups whose proof images have outlived the cutoff
-- and are still stored (DB_SCHEME §10).
SELECT id FROM groups
WHERE proofs_purged_at IS NULL
  AND ((status = 'completed' AND completed_at < sqlc.arg(cutoff)::timestamptz)
    OR (status = 'closed' AND closed_at < sqlc.arg(cutoff)::timestamptz))
ORDER BY id
LIMIT sqlc.arg(max_groups);

-- name: ListGroupProofKeys :many
-- Every stored payment and payout proof object of the group.
SELECT pr.object_key::text AS object_key
FROM payment_proofs pr
JOIN payments pay ON pay.id = pr.payment_id
WHERE pay.group_id = sqlc.arg(group_id)
UNION
SELECT po.proof_key::text
FROM payouts po
JOIN periods p ON p.id = po.period_id
WHERE p.group_id = sqlc.arg(group_id) AND po.proof_key IS NOT NULL;

-- name: MarkGroupProofsPurged :exec
UPDATE groups SET proofs_purged_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id) AND proofs_purged_at IS NULL;
