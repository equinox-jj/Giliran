-- name: GetMembership :one
-- The caller's active membership: every permission check (GetMemberRole in
-- DB_SCHEME §8) starts here.
SELECT * FROM group_members
WHERE group_id = $1 AND user_id = $2 AND status = 'active';

-- name: GetMemberForUpdate :one
SELECT * FROM group_members
WHERE id = $1 AND group_id = $2
FOR UPDATE;

-- name: CreateMember :one
INSERT INTO group_members (
    id, group_id, user_id, guest_name, guest_phone, role, joined_at, created_at, updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6, sqlc.arg(now), sqlc.arg(now), sqlc.arg(now)
)
RETURNING *;

-- name: ListMemberViews :many
-- Members with their slot, account and win, ordered by slot number. Members
-- whose slot was dropped (a draft group shrinking) are left out.
SELECT
    sqlc.embed(gm),
    s.id AS slot_id,
    s.slot_no,
    s.fixed_order_position,
    u.name AS user_name,
    u.avatar_key AS user_avatar_key,
    wp.period_no AS won_period_no
FROM group_members gm
JOIN slot_members sm ON sm.member_id = gm.id
JOIN slots s ON s.id = sm.slot_id
LEFT JOIN users u ON u.id = gm.user_id
LEFT JOIN periods wp ON wp.winner_slot_id = s.id
WHERE gm.group_id = sqlc.arg(group_id)
  AND (gm.status = 'active' OR sqlc.arg(include_inactive)::bool)
ORDER BY s.slot_no, gm.joined_at;

-- name: GetMemberView :one
SELECT
    sqlc.embed(gm),
    s.id AS slot_id,
    s.slot_no,
    s.fixed_order_position,
    u.name AS user_name,
    u.avatar_key AS user_avatar_key,
    wp.period_no AS won_period_no
FROM group_members gm
JOIN slot_members sm ON sm.member_id = gm.id
JOIN slots s ON s.id = sm.slot_id
LEFT JOIN users u ON u.id = gm.user_id
LEFT JOIN periods wp ON wp.winner_slot_id = s.id
WHERE gm.id = sqlc.arg(id) AND gm.group_id = sqlc.arg(group_id)
LIMIT 1;

-- name: CountActiveMembers :one
SELECT count(*)::int FROM group_members
WHERE group_id = $1 AND status = 'active';

-- name: UpdateGuest :one
UPDATE group_members
SET guest_name = $2, guest_phone = $3
WHERE id = $1 AND user_id IS NULL
RETURNING *;

-- name: SetMemberClaimToken :exec
UPDATE group_members
SET claim_token_hash = $2, claim_token_expires_at = $3
WHERE id = $1;

-- name: GetMemberByClaimTokenHashForUpdate :one
SELECT * FROM group_members
WHERE claim_token_hash = $1
FOR UPDATE;

-- name: ClaimGuest :one
-- The account takes over the guest row, so the slot keeps its history. The
-- guest-only fields are cleared (an account row has no guest name).
UPDATE group_members
SET user_id = $2, guest_name = NULL, guest_phone = NULL,
    claim_token_hash = NULL, claim_token_expires_at = NULL
WHERE id = $1 AND user_id IS NULL
RETURNING *;

-- name: SetMemberStatus :one
UPDATE group_members
SET status = $2, left_at = $3
WHERE id = $1
RETURNING *;

-- name: SetMemberRole :exec
UPDATE group_members
SET role = $2
WHERE id = $1;

-- name: MemberHasWon :one
SELECT EXISTS (
    SELECT 1 FROM periods p
    JOIN slot_members sm ON sm.slot_id = p.winner_slot_id
    WHERE sm.member_id = $1
)::bool;

-- name: MemberHasOutstandingObligations :one
-- A past winner who still owes a payment in some period of the group,
-- including periods that have not opened yet (FR-MEM-05).
SELECT (
    EXISTS (
        SELECT 1 FROM periods p
        JOIN slot_members sm ON sm.slot_id = p.winner_slot_id
        WHERE sm.member_id = sqlc.arg(member_id))
    AND EXISTS (
        SELECT 1 FROM periods p
        WHERE p.group_id = sqlc.arg(group_id)
          AND NOT EXISTS (
              SELECT 1 FROM payments pay
              WHERE pay.period_id = p.id AND pay.member_id = sqlc.arg(member_id) AND pay.status = 'paid'))
)::bool;

-- name: MemberHasPaymentsInOpenPeriods :one
-- Whether the member has a payment past unpaid in an open period, which
-- blocks removal (FR-MEM-06).
SELECT EXISTS (
    SELECT 1 FROM payments pay
    JOIN periods p ON p.id = pay.period_id
    WHERE pay.member_id = $1 AND p.status = 'open' AND pay.status <> 'unpaid'
)::bool;

-- name: ListUserMemberships :many
-- The user's active memberships with their group's status, for account
-- deletion.
SELECT sqlc.embed(gm), g.status AS group_status
FROM group_members gm
JOIN groups g ON g.id = gm.group_id
WHERE gm.user_id = $1 AND gm.status = 'active'
ORDER BY gm.joined_at;

-- name: ListActiveMemberUserIDs :many
-- The accounts of the group's active members, for push notifications. An
-- empty roles list means every role; guests and deleted accounts have none.
SELECT DISTINCT gm.user_id::uuid AS user_id
FROM group_members gm
JOIN users u ON u.id = gm.user_id AND u.deleted_at IS NULL
WHERE gm.group_id = sqlc.arg(group_id) AND gm.status = 'active'
  AND (cardinality(sqlc.arg(roles)::text[]) = 0 OR gm.role = ANY(sqlc.arg(roles)::text[]))
ORDER BY 1;
