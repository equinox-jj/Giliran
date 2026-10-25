BEGIN;

-- Fails if a deleted user already had their phone cleared: that data is gone
-- and cannot be restored, so the rollback refuses rather than invent a value.
ALTER TABLE users DROP CONSTRAINT users_phone_required_unless_deleted;
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;

COMMIT;
