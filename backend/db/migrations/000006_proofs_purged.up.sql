BEGIN;

-- When the cleanup job deleted the group's payment and payout proof images,
-- RETENTION_PAYMENT_PROOFS after it completed or closed (DB_SCHEME §10). The
-- proof rows stay; their objects are gone, so no URL is handed out.
ALTER TABLE groups ADD COLUMN proofs_purged_at timestamptz;

COMMIT;
