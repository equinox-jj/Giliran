-- name: CreatePayout :one
INSERT INTO payouts (id, period_id, winner_member_id, amount, proof_key, note, recorded_by, recorded_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, sqlc.arg(now))
RETURNING *;

-- name: GetPayoutByPeriod :one
SELECT * FROM payouts
WHERE period_id = $1;

-- name: ConfirmPayout :one
-- The winner confirms receipt once.
UPDATE payouts
SET confirmed_by = sqlc.arg(confirmed_by), confirmed_at = sqlc.arg(now)
WHERE id = sqlc.arg(id) AND confirmed_at IS NULL
RETURNING *;
