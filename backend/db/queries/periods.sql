-- name: CreatePeriods :exec
-- Every period of a starting group, all upcoming.
INSERT INTO periods (id, group_id, period_no, due_date, draw_date, draw_algorithm, created_at, updated_at)
SELECT
    unnest(sqlc.arg(ids)::uuid[]),
    sqlc.arg(group_id)::uuid,
    unnest(sqlc.arg(period_nos)::smallint[]),
    unnest(sqlc.arg(due_dates)::date[]),
    unnest(sqlc.arg(draw_dates)::date[]),
    sqlc.arg(draw_algorithm)::text,
    sqlc.arg(now)::timestamptz,
    sqlc.arg(now)::timestamptz;

-- name: GetPeriod :one
SELECT * FROM periods
WHERE id = $1 AND group_id = $2;

-- name: GetPeriodForUpdate :one
SELECT * FROM periods
WHERE id = $1 AND group_id = $2
FOR UPDATE;

-- name: GetPeriodByNo :one
SELECT * FROM periods
WHERE group_id = $1 AND period_no = $2;

-- name: OpenPeriod :one
-- Publishes the seed hash (NULL for fixed-order groups). Only an upcoming
-- period opens.
UPDATE periods
SET status = 'open', seed_hash = sqlc.narg(seed_hash)
WHERE id = sqlc.arg(id) AND status = 'upcoming'
RETURNING *;

-- name: CreatePeriodSeed :exec
INSERT INTO period_seeds (period_id, seed, created_at)
VALUES ($1, $2, sqlc.arg(now));

-- name: ListPeriodViews :many
-- The group's periods with the winner's slot and payout state, in order.
SELECT
    sqlc.embed(p),
    ws.slot_no AS winner_slot_no,
    (po.id IS NOT NULL)::bool AS payout_recorded,
    (po.confirmed_at IS NOT NULL)::bool AS payout_confirmed
FROM periods p
LEFT JOIN slots ws ON ws.id = p.winner_slot_id
LEFT JOIN payouts po ON po.period_id = p.id
WHERE p.group_id = $1
ORDER BY p.period_no;

-- name: GetPeriodView :one
SELECT
    sqlc.embed(p),
    ws.slot_no AS winner_slot_no,
    (po.id IS NOT NULL)::bool AS payout_recorded,
    (po.confirmed_at IS NOT NULL)::bool AS payout_confirmed
FROM periods p
LEFT JOIN slots ws ON ws.id = p.winner_slot_id
LEFT JOIN payouts po ON po.period_id = p.id
WHERE p.id = $1 AND p.group_id = $2;

-- name: GetPeriodSeed :one
SELECT * FROM period_seeds
WHERE period_id = $1;

-- name: RecordDraw :one
-- Stores the result and reveals the seed (NULL for fixed-order groups). Only
-- an open period is drawn; the guard trigger freezes the result afterwards.
UPDATE periods
SET status = 'drawn',
    seed = sqlc.narg(seed),
    eligible_slot_ids = sqlc.arg(eligible_slot_ids)::uuid[],
    winner_slot_id = sqlc.arg(winner_slot_id),
    verification_code = sqlc.arg(verification_code),
    drawn_at = sqlc.arg(drawn_at),
    drawn_by = sqlc.arg(drawn_by)
WHERE id = sqlc.arg(id) AND status = 'open'
RETURNING *;

-- name: ClosePeriod :one
-- Recording the payout closes a drawn period.
UPDATE periods
SET status = 'closed'
WHERE id = $1 AND status = 'drawn'
RETURNING *;

-- name: VerificationCodeExists :one
SELECT EXISTS (SELECT 1 FROM periods WHERE verification_code = $1)::bool;

-- name: GetDrawByCode :one
-- A drawn period by its public verification code (GetDrawByCode in
-- DB_SCHEME §8), with what the public page shows about its group.
SELECT
    sqlc.embed(p),
    g.name AS group_name,
    g.total_slots,
    ps.created_at AS seed_hash_published_at
FROM periods p
JOIN groups g ON g.id = p.group_id
LEFT JOIN period_seeds ps ON ps.period_id = p.id
WHERE p.verification_code = $1 AND p.winner_slot_id IS NOT NULL;
