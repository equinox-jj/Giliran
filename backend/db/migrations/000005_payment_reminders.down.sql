BEGIN;

ALTER TABLE payments DROP COLUMN last_reminded_at;

COMMIT;
