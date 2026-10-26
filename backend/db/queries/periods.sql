-- name: CreatePeriods :exec
-- Every period of a starting group, all upcoming.
INSERT INTO periods (id, group_id, period_no, due_date, draw_date, created_at, updated_at)
SELECT
    unnest(sqlc.arg(ids)::uuid[]),
    sqlc.arg(group_id)::uuid,
    unnest(sqlc.arg(period_nos)::smallint[]),
    unnest(sqlc.arg(due_dates)::date[]),
    unnest(sqlc.arg(draw_dates)::date[]),
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
