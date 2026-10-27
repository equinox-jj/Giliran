BEGIN;

-- Email OTP replaces Firebase phone auth (DB_SCHEME §11.1). Existing users
-- have no email to backfill, and there is no production data yet, so the
-- migration refuses rather than leave accounts that can never sign in.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM users WHERE deleted_at IS NULL) THEN
        RAISE EXCEPTION '000007_email_otp: active users have no email; reset the dev database and migrate again';
    END IF;
END
$$;

-- ---------- users: email is the identity, phone is optional and unverified ----------

ALTER TABLE users
    ADD COLUMN email text CHECK (email IS NULL OR (email = lower(email)
                                 AND char_length(email) <= 254
                                 AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
    ADD COLUMN email_verified_at timestamptz;

DROP INDEX users_firebase_uid_active_uq;
ALTER TABLE users DROP COLUMN firebase_uid;

DROP INDEX users_phone_active_uq;
ALTER TABLE users DROP CONSTRAINT users_phone_required_unless_deleted;

-- cleared on account deletion (§10), required otherwise
ALTER TABLE users ADD CONSTRAINT users_email_required_unless_deleted
    CHECK (deleted_at IS NOT NULL OR (email IS NOT NULL AND email_verified_at IS NOT NULL));

CREATE UNIQUE INDEX users_email_active_uq
    ON users (email) WHERE deleted_at IS NULL;

-- ---------- sessions: phone_changed becomes email_changed ----------

ALTER TABLE sessions DROP CONSTRAINT sessions_revoked_reason_check;
UPDATE sessions SET revoked_reason = 'email_changed' WHERE revoked_reason = 'phone_changed';
ALTER TABLE sessions ADD CONSTRAINT sessions_revoked_reason_check
    CHECK (revoked_reason IN (
        'rotated', 'logout', 'signed_out_by_user', 'reuse_detected',
        'pin_reset', 'email_changed', 'account_deleted', 'expired'));

-- ---------- group_members: guests are claimed only through claim links ----------

DROP INDEX group_members_guest_phone_idx;

-- ---------- email_otp_requests ----------

CREATE TABLE email_otp_requests (
    id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    purpose              text        NOT NULL CHECK (purpose IN ('sign_in', 'reset_pin', 'change_email')),
    email                text        NOT NULL CHECK (email = lower(email) AND char_length(email) <= 254),
    user_id              uuid        REFERENCES users (id) ON DELETE CASCADE,
    code_hash            text        NOT NULL CHECK (code_hash ~ '^[0-9a-f]{64}$'),
    attempts             smallint    NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
    resend_count         smallint    NOT NULL DEFAULT 0 CHECK (resend_count BETWEEN 0 AND 5),
    last_sent_at         timestamptz NOT NULL DEFAULT now(),
    send_status          text        NOT NULL DEFAULT 'queued'
                                     CHECK (send_status IN ('queued', 'sent', 'failed', 'skipped')),
    provider_message_id  text,
    device_name          text        CHECK (device_name IS NULL OR char_length(device_name) <= 100),
    device_platform      text        NOT NULL CHECK (device_platform IN ('android', 'ios')),
    fcm_token            text,
    requester_ip         inet,
    status               text        NOT NULL DEFAULT 'pending'
                                     CHECK (status IN ('pending', 'consumed', 'expired', 'locked', 'cancelled')),
    expires_at           timestamptz NOT NULL,
    consumed_at          timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),
    CHECK (purpose <> 'change_email' OR user_id IS NOT NULL),
    CHECK (send_status <> 'skipped' OR (purpose = 'reset_pin' AND user_id IS NULL)),
    CHECK ((status = 'consumed') = (consumed_at IS NOT NULL)),
    CHECK (status <> 'consumed' OR user_id IS NOT NULL),
    CHECK (status <> 'locked' OR attempts = 5),
    CHECK (expires_at > last_sent_at)
);

-- one live request per email and purpose
CREATE UNIQUE INDEX email_otp_requests_one_pending_uq
    ON email_otp_requests (email, purpose) WHERE status = 'pending';
CREATE INDEX email_otp_requests_expiry_idx
    ON email_otp_requests (expires_at) WHERE status = 'pending';
CREATE INDEX email_otp_requests_email_recent_idx
    ON email_otp_requests (email, created_at DESC);
CREATE INDEX email_otp_requests_ip_recent_idx
    ON email_otp_requests (requester_ip, created_at DESC);

COMMIT;
