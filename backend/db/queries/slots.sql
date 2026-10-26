-- name: CreateSlots :exec
INSERT INTO slots (id, group_id, slot_no, created_at)
SELECT unnest(sqlc.arg(ids)::uuid[]), sqlc.arg(group_id)::uuid, unnest(sqlc.arg(slot_nos)::smallint[]), sqlc.arg(now)::timestamptz;

-- name: ListSlots :many
SELECT * FROM slots
WHERE group_id = $1
ORDER BY slot_no;

-- name: LowestFreeSlot :one
-- The lowest slot with no active holder that has not won yet. Lock the group
-- first so two joins never pick the same slot.
SELECT s.* FROM slots s
WHERE s.group_id = $1
  AND NOT EXISTS (
      SELECT 1 FROM slot_members sm JOIN group_members gm ON gm.id = sm.member_id
      WHERE sm.slot_id = s.id AND gm.status = 'active')
  AND NOT EXISTS (SELECT 1 FROM periods p WHERE p.winner_slot_id = s.id)
ORDER BY s.slot_no
LIMIT 1;

-- name: CountFilledSlots :one
SELECT count(*)::int FROM slots s
WHERE s.group_id = $1
  AND EXISTS (
      SELECT 1 FROM slot_members sm JOIN group_members gm ON gm.id = sm.member_id
      WHERE sm.slot_id = s.id AND gm.status = 'active');

-- name: AssignSlot :exec
INSERT INTO slot_members (slot_id, member_id, created_at)
VALUES ($1, $2, sqlc.arg(now));

-- name: ListActiveHoldersAbove :many
-- Active members holding a slot numbered above slot_no, for shrinking a
-- draft group.
SELECT sm.slot_id, sm.member_id FROM slot_members sm
JOIN slots s ON s.id = sm.slot_id
JOIN group_members gm ON gm.id = sm.member_id
WHERE s.group_id = sqlc.arg(group_id) AND s.slot_no > sqlc.arg(slot_no) AND gm.status = 'active'
ORDER BY s.slot_no;

-- name: MoveSlotMember :exec
UPDATE slot_members
SET slot_id = sqlc.arg(to_slot_id)
WHERE slot_id = sqlc.arg(from_slot_id) AND member_id = sqlc.arg(member_id);

-- name: DeleteSlotsAbove :exec
-- Drops slots of a draft group; their slot_members rows cascade.
DELETE FROM slots
WHERE group_id = $1 AND slot_no > $2;

-- name: ClearFixedOrder :exec
UPDATE slots
SET fixed_order_position = NULL
WHERE group_id = $1;

-- name: SetFixedOrderPositions :exec
-- Clear the order first: the (group_id, fixed_order_position) index is not
-- deferrable.
UPDATE slots s
SET fixed_order_position = t.position
FROM (SELECT unnest(sqlc.arg(slot_ids)::uuid[]) AS slot_id, unnest(sqlc.arg(positions)::smallint[]) AS position) AS t
WHERE s.id = t.slot_id AND s.group_id = sqlc.arg(group_id);

-- name: ListEligibleSlots :many
-- Slots of the group that have not won, by slot number: the draw's eligible
-- list (DB_SCHEME §5 step 2).
SELECT s.* FROM slots s
WHERE s.group_id = $1
  AND NOT EXISTS (SELECT 1 FROM periods p WHERE p.winner_slot_id = s.id)
ORDER BY s.slot_no;
