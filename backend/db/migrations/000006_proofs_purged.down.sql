BEGIN;

ALTER TABLE groups DROP COLUMN proofs_purged_at;

COMMIT;
