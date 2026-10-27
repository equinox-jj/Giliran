BEGIN;

-- Fails while an active user has no phone: phone was optional under email
-- sign-in, and the rollback refuses rather than invent a number. The email
-- addresses are dropped and cannot be restored.

DROP TABLE email_otp_requests;

CREATE INDEX group_members_guest_phone_idx ON group_members (guest_phone) WHERE user_id IS NULL AND guest_phone IS NOT NULL;

ALTER TABLE sessions DROP CONSTRAINT sessions_revoked_reason_check;
UPDATE sessions SET revoked_reason = 'phone_changed' WHERE revoked_reason = 'email_changed';
ALTER TABLE sessions ADD CONSTRAINT sessions_revoked_reason_check
    CHECK (revoked_reason IN (
        'rotated', 'logout', 'signed_out_by_user', 'reuse_detected',
        'pin_reset', 'phone_changed', 'account_deleted', 'expired'));

DROP INDEX users_email_active_uq;
ALTER TABLE users DROP CONSTRAINT users_email_required_unless_deleted;
ALTER TABLE users DROP COLUMN email_verified_at, DROP COLUMN email;

ALTER TABLE users ADD CONSTRAINT users_phone_required_unless_deleted
    CHECK (phone IS NOT NULL OR deleted_at IS NOT NULL);
CREATE UNIQUE INDEX users_phone_active_uq
    ON users (phone) WHERE deleted_at IS NULL;

ALTER TABLE users ADD COLUMN firebase_uid text;
CREATE UNIQUE INDEX users_firebase_uid_active_uq
    ON users (firebase_uid) WHERE firebase_uid IS NOT NULL AND deleted_at IS NULL;

COMMIT;
