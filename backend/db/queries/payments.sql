-- name: ListSlotHolders :many
-- Active members holding a slot of the group, with their share in basis
-- points (share_pct 100.00 → 10000), by slot number.
SELECT sm.slot_id, sm.member_id, (sm.share_pct * 100)::int AS share_basis_points
FROM slot_members sm
JOIN slots s ON s.id = sm.slot_id
JOIN group_members gm ON gm.id = sm.member_id
WHERE s.group_id = $1 AND gm.status = 'active'
ORDER BY s.slot_no, gm.joined_at;

-- name: CreatePayments :exec
INSERT INTO payments (id, group_id, period_id, slot_id, member_id, amount, created_at, updated_at)
SELECT
    unnest(sqlc.arg(ids)::uuid[]),
    sqlc.arg(group_id)::uuid,
    sqlc.arg(period_id)::uuid,
    unnest(sqlc.arg(slot_ids)::uuid[]),
    unnest(sqlc.arg(member_ids)::uuid[]),
    unnest(sqlc.arg(amounts)::bigint[]),
    sqlc.arg(now)::timestamptz,
    sqlc.arg(now)::timestamptz;

-- name: ListPeriodPayments :many
-- A period's payments by slot number (ListPaymentBoard in DB_SCHEME §8),
-- with the current proof.
SELECT
    sqlc.embed(pay),
    pr.object_key AS proof_object_key,
    pr.content_type AS proof_content_type,
    pr.created_at AS proof_created_at
FROM payments pay
JOIN slots s ON s.id = pay.slot_id
JOIN group_members gm ON gm.id = pay.member_id
LEFT JOIN payment_proofs pr ON pr.id = pay.current_proof_id
WHERE pay.period_id = $1
ORDER BY s.slot_no, gm.joined_at;

-- name: GetPayment :one
SELECT
    sqlc.embed(pay),
    pr.object_key AS proof_object_key,
    pr.content_type AS proof_content_type,
    pr.created_at AS proof_created_at
FROM payments pay
LEFT JOIN payment_proofs pr ON pr.id = pay.current_proof_id
WHERE pay.id = $1 AND pay.group_id = $2;

-- name: GetPaymentForUpdate :one
SELECT * FROM payments
WHERE id = $1 AND group_id = $2
FOR UPDATE;

-- name: SetPaymentProof :one
UPDATE payments
SET status = 'pending_review', current_proof_id = sqlc.arg(proof_id), reject_reason = NULL,
    reviewed_by = NULL, reviewed_at = NULL
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: SetPaymentPaid :one
-- Approve (method transfer) or mark paid directly (any method, with a note).
UPDATE payments
SET status = 'paid', method = sqlc.arg(method), note = sqlc.narg(note),
    paid_at = sqlc.arg(now)::timestamptz, reviewed_by = sqlc.arg(reviewed_by), reviewed_at = sqlc.arg(now)::timestamptz,
    reject_reason = NULL
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: RejectPayment :one
UPDATE payments
SET status = 'rejected', reject_reason = sqlc.arg(reason),
    reviewed_by = sqlc.arg(reviewed_by), reviewed_at = sqlc.arg(now)::timestamptz
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: GetPaymentSummary :one
SELECT
    count(*)::int AS total_count,
    count(*) FILTER (WHERE status = 'paid')::int AS paid_count,
    count(*) FILTER (WHERE status = 'pending_review')::int AS pending_review_count,
    count(*) FILTER (WHERE status = 'unpaid')::int AS unpaid_count,
    count(*) FILTER (WHERE status = 'rejected')::int AS rejected_count,
    COALESCE(sum(amount) FILTER (WHERE status = 'paid'), 0)::bigint AS collected_amount,
    COALESCE(sum(amount), 0)::bigint AS expected_amount
FROM payments
WHERE period_id = $1;

-- name: CreatePaymentProof :one
INSERT INTO payment_proofs (id, payment_id, object_key, content_type, size_bytes, uploaded_by, created_at)
VALUES ($1, $2, $3, $4, $5, $6, sqlc.arg(now))
RETURNING *;

-- name: ListPaymentProofs :many
SELECT * FROM payment_proofs
WHERE payment_id = $1
ORDER BY created_at DESC, id DESC;

-- name: ListObligations :many
-- Per past winner of the group (DB_SCHEME §8): the period won and the later
-- periods not yet paid. Open, drawn and closed periods have a payment row;
-- upcoming ones do not yet, so they are counted separately and priced at the
-- member's share by the caller.
WITH winners AS (
    SELECT sm.member_id, (sm.share_pct * 100)::int AS share_basis_points, p.period_no AS won_period_no
    FROM periods p
    JOIN slot_members sm ON sm.slot_id = p.winner_slot_id
    WHERE p.group_id = sqlc.arg(group_id)
)
SELECT
    w.member_id,
    w.won_period_no::smallint AS won_period_no,
    w.share_basis_points::int AS share_basis_points,
    count(pay.id) FILTER (WHERE pay.status <> 'paid')::int AS unpaid_count,
    COALESCE(sum(pay.amount) FILTER (WHERE pay.status <> 'paid'), 0)::bigint AS unpaid_amount,
    count(pay.id) FILTER (WHERE pay.status <> 'paid' AND lp.due_date < sqlc.arg(today)::date)::int AS overdue_unpaid_count,
    COALESCE(sum(pay.amount) FILTER (WHERE pay.status <> 'paid' AND lp.due_date < sqlc.arg(today)::date), 0)::bigint AS overdue_unpaid_amount,
    count(lp.id) FILTER (WHERE lp.status = 'upcoming' AND pay.id IS NULL)::int AS upcoming_count,
    count(lp.id) FILTER (WHERE lp.status = 'upcoming' AND pay.id IS NULL AND lp.due_date < sqlc.arg(today)::date)::int AS overdue_upcoming_count
FROM winners w
LEFT JOIN periods lp ON lp.group_id = sqlc.arg(group_id) AND lp.period_no > w.won_period_no
LEFT JOIN payments pay ON pay.period_id = lp.id AND pay.member_id = w.member_id
GROUP BY w.member_id, w.won_period_no, w.share_basis_points
ORDER BY w.won_period_no;

-- name: ListReminderTargets :many
-- A period's payments with what decides whether a push reminder can reach
-- the payer: account, phone, notification setting and a device token.
SELECT
    pay.id AS payment_id,
    pay.member_id,
    pay.status,
    pay.last_reminded_at,
    gm.user_id,
    gm.guest_phone,
    u.phone AS user_phone,
    COALESCE(us.notify_payment_reminders, false)::bool AS notify_payment_reminders,
    EXISTS (
        SELECT 1 FROM sessions se
        WHERE se.user_id = gm.user_id AND se.revoked_at IS NULL
          AND se.expires_at > sqlc.arg(now)::timestamptz AND se.fcm_token IS NOT NULL
    )::bool AS has_device
FROM payments pay
JOIN group_members gm ON gm.id = pay.member_id
JOIN slots s ON s.id = pay.slot_id
LEFT JOIN users u ON u.id = gm.user_id AND u.deleted_at IS NULL
LEFT JOIN user_settings us ON us.user_id = u.id
WHERE pay.period_id = sqlc.arg(period_id)
ORDER BY s.slot_no, gm.joined_at;

-- name: MarkPaymentsReminded :exec
UPDATE payments SET last_reminded_at = sqlc.arg(now)::timestamptz
WHERE id = ANY(sqlc.arg(ids)::uuid[]);
