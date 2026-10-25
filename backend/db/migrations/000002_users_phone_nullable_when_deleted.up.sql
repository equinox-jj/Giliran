BEGIN;

-- Account deletion clears the phone number (DB_SCHEME §10), so phone may be
-- NULL, but only on a deleted user. The format CHECK already passes NULL and
-- users_phone_active_uq only covers active users.
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_phone_required_unless_deleted
    CHECK (phone IS NOT NULL OR deleted_at IS NOT NULL);

COMMIT;
