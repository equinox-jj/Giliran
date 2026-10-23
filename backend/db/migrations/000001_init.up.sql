BEGIN;

-- =====================================================================
-- Giliran — initial schema (PostgreSQL 16+)
-- =====================================================================

-- ---------- helper functions ----------

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION prevent_activity_log_change() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'activity_logs is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION guard_period_draw() RETURNS trigger AS $$
BEGIN
    IF OLD.seed_hash IS NOT NULL AND NEW.seed_hash IS DISTINCT FROM OLD.seed_hash THEN
        RAISE EXCEPTION 'seed_hash is immutable once published';
    END IF;
    IF OLD.winner_slot_id IS NOT NULL AND (
           NEW.winner_slot_id    IS DISTINCT FROM OLD.winner_slot_id
        OR NEW.seed              IS DISTINCT FROM OLD.seed
        OR NEW.eligible_slot_ids IS DISTINCT FROM OLD.eligible_slot_ids
        OR NEW.drawn_at          IS DISTINCT FROM OLD.drawn_at
        OR NEW.drawn_by          IS DISTINCT FROM OLD.drawn_by
    ) THEN
        RAISE EXCEPTION 'draw result is immutable';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------- users ----------

CREATE TABLE users (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    phone             text        NOT NULL CHECK (phone ~ '^\+62[0-9]{8,13}$'),
    firebase_uid      text,
    name              text        CHECK (name IS NULL OR char_length(name) BETWEEN 2 AND 50),
    avatar_key        text,
    pin_hash          text,
    pin_failed_count  smallint    NOT NULL DEFAULT 0 CHECK (pin_failed_count >= 0),
    pin_locked_until  timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    deleted_at        timestamptz
);

CREATE UNIQUE INDEX users_phone_active_uq
    ON users (phone) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX users_firebase_uid_active_uq
    ON users (firebase_uid) WHERE firebase_uid IS NOT NULL AND deleted_at IS NULL;

CREATE TRIGGER users_set_updated_at
    BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- user_settings ----------

CREATE TABLE user_settings (
    user_id                   uuid        PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    language                  text        NOT NULL DEFAULT 'id' CHECK (language IN ('id', 'en')),
    notify_payment_reminders  boolean     NOT NULL DEFAULT true,
    notify_draw_results       boolean     NOT NULL DEFAULT true,
    notify_group_activity     boolean     NOT NULL DEFAULT true,
    updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER user_settings_set_updated_at
    BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- sessions ----------

CREATE TABLE sessions (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    family_id           uuid        NOT NULL,
    refresh_token_hash  text        NOT NULL UNIQUE,
    replaced_by_id      uuid        REFERENCES sessions (id) ON DELETE SET NULL,
    device_name         text,
    device_platform     text        NOT NULL DEFAULT 'android' CHECK (device_platform IN ('android', 'ios')),
    fcm_token           text,
    last_active_at      timestamptz NOT NULL DEFAULT now(),
    expires_at          timestamptz NOT NULL,
    revoked_at          timestamptz,
    revoked_reason      text        CHECK (revoked_reason IN (
                            'rotated', 'logout', 'signed_out_by_user', 'reuse_detected',
                            'pin_reset', 'phone_changed', 'account_deleted', 'expired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    CHECK ((revoked_at IS NULL) = (revoked_reason IS NULL))
);

CREATE INDEX sessions_user_active_idx ON sessions (user_id) WHERE revoked_at IS NULL;
CREATE INDEX sessions_family_idx      ON sessions (family_id);

-- ---------- groups ----------

CREATE TABLE groups (
    id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id          uuid        NOT NULL REFERENCES users (id),
    name                  text        NOT NULL CHECK (char_length(name) BETWEEN 3 AND 60),
    amount                bigint      NOT NULL CHECK (amount BETWEEN 10000 AND 100000000),
    period_type           text        NOT NULL CHECK (period_type IN ('weekly', 'monthly')),
    total_slots           smallint    NOT NULL CHECK (total_slots BETWEEN 2 AND 50),
    draw_method           text        NOT NULL CHECK (draw_method IN ('random', 'fixed_order')),
    start_date            date        NOT NULL,
    reminder_days_before  smallint    NOT NULL DEFAULT 2 CHECK (reminder_days_before BETWEEN 0 AND 7),
    status                text        NOT NULL DEFAULT 'draft'
                                      CHECK (status IN ('draft', 'active', 'completed', 'closed')),
    invite_code           text        NOT NULL UNIQUE CHECK (invite_code ~ '^[A-Z0-9]{8}$'),
    bank_name             text,
    bank_account_number   text        CHECK (bank_account_number IS NULL OR bank_account_number ~ '^[0-9]{6,20}$'),
    bank_account_holder   text,
    qris_payload          text,
    qris_image_key        text,
    started_at            timestamptz,
    completed_at          timestamptz,
    closed_at             timestamptz,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    CHECK (status = 'draft' OR started_at IS NOT NULL OR status = 'closed')
);

CREATE INDEX groups_organizer_idx ON groups (organizer_id);

CREATE TRIGGER groups_set_updated_at
    BEFORE UPDATE ON groups FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- group_members ----------

CREATE TABLE group_members (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id                uuid        NOT NULL REFERENCES groups (id),
    user_id                 uuid        REFERENCES users (id),
    guest_name              text        CHECK (guest_name IS NULL OR char_length(guest_name) BETWEEN 2 AND 50),
    guest_phone             text        CHECK (guest_phone IS NULL OR guest_phone ~ '^\+62[0-9]{8,13}$'),
    role                    text        NOT NULL DEFAULT 'member'
                                        CHECK (role IN ('organizer', 'co_organizer', 'member')),
    status                  text        NOT NULL DEFAULT 'active'
                                        CHECK (status IN ('active', 'left', 'removed')),
    claim_token_hash        text        UNIQUE,
    claim_token_expires_at  timestamptz,
    joined_at               timestamptz NOT NULL DEFAULT now(),
    left_at                 timestamptz,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    -- exactly one of: an account, or a guest name
    CHECK ((user_id IS NOT NULL AND guest_name IS NULL) OR (user_id IS NULL AND guest_name IS NOT NULL)),
    -- guests can only be plain members
    CHECK (user_id IS NOT NULL OR role = 'member'),
    CHECK ((status = 'active') = (left_at IS NULL))
);

CREATE UNIQUE INDEX group_members_user_active_uq
    ON group_members (group_id, user_id) WHERE user_id IS NOT NULL AND status = 'active';
CREATE UNIQUE INDEX group_members_one_organizer_uq
    ON group_members (group_id) WHERE role = 'organizer' AND status = 'active';
CREATE INDEX group_members_user_idx  ON group_members (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX group_members_group_idx ON group_members (group_id, status);
CREATE INDEX group_members_guest_phone_idx ON group_members (guest_phone) WHERE user_id IS NULL AND guest_phone IS NOT NULL;

CREATE TRIGGER group_members_set_updated_at
    BEFORE UPDATE ON group_members FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- slots ----------

CREATE TABLE slots (
    id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id              uuid        NOT NULL REFERENCES groups (id),
    slot_no               smallint    NOT NULL CHECK (slot_no >= 1),
    fixed_order_position  smallint    CHECK (fixed_order_position IS NULL OR fixed_order_position >= 1),
    label                 text,
    created_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (group_id, slot_no),
    UNIQUE (group_id, fixed_order_position)
);

-- ---------- slot_members ----------

CREATE TABLE slot_members (
    slot_id     uuid          NOT NULL REFERENCES slots (id) ON DELETE CASCADE,
    member_id   uuid          NOT NULL REFERENCES group_members (id),
    share_pct   numeric(5,2)  NOT NULL DEFAULT 100 CHECK (share_pct > 0 AND share_pct <= 100),
    created_at  timestamptz   NOT NULL DEFAULT now(),
    PRIMARY KEY (slot_id, member_id)
);

CREATE INDEX slot_members_member_idx ON slot_members (member_id);

-- ---------- periods ----------

CREATE TABLE periods (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id           uuid        NOT NULL REFERENCES groups (id),
    period_no          smallint    NOT NULL CHECK (period_no >= 1),
    due_date           date        NOT NULL,
    draw_date          date        NOT NULL,
    status             text        NOT NULL DEFAULT 'upcoming'
                                   CHECK (status IN ('upcoming', 'open', 'drawn', 'closed')),
    seed_hash          text        CHECK (seed_hash IS NULL OR seed_hash ~ '^[0-9a-f]{64}$'),
    seed               text        CHECK (seed IS NULL OR seed ~ '^[0-9a-f]{64}$'),
    draw_algorithm     text        NOT NULL DEFAULT 'hmac-sha256-v1',
    eligible_slot_ids  uuid[],
    winner_slot_id     uuid        REFERENCES slots (id),
    verification_code  text        UNIQUE CHECK (verification_code IS NULL OR verification_code ~ '^[A-Z0-9]{10}$'),
    drawn_at           timestamptz,
    drawn_by           uuid        REFERENCES users (id),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (group_id, period_no),
    CHECK (draw_date >= due_date),
    -- a seed is only revealed together with a result
    CHECK (seed IS NULL OR winner_slot_id IS NOT NULL),
    -- drawn and closed periods always carry a complete result
    CHECK (status NOT IN ('drawn', 'closed')
           OR (winner_slot_id IS NOT NULL AND drawn_at IS NOT NULL AND drawn_by IS NOT NULL))
);

-- each slot wins at most once per group
CREATE UNIQUE INDEX periods_winner_once_uq
    ON periods (group_id, winner_slot_id) WHERE winner_slot_id IS NOT NULL;
CREATE INDEX periods_status_due_idx ON periods (status, due_date);

CREATE TRIGGER periods_set_updated_at
    BEFORE UPDATE ON periods FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER periods_guard_draw
    BEFORE UPDATE ON periods FOR EACH ROW EXECUTE FUNCTION guard_period_draw();

-- ---------- payments ----------

CREATE TABLE payments (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id          uuid        NOT NULL REFERENCES groups (id),
    period_id         uuid        NOT NULL REFERENCES periods (id),
    slot_id           uuid        NOT NULL REFERENCES slots (id),
    member_id         uuid        NOT NULL REFERENCES group_members (id),
    amount            bigint      NOT NULL CHECK (amount > 0),
    status            text        NOT NULL DEFAULT 'unpaid'
                                  CHECK (status IN ('unpaid', 'pending_review', 'paid', 'rejected')),
    method            text        CHECK (method IN ('transfer', 'cash', 'other')),
    current_proof_id  uuid,
    note              text        CHECK (note IS NULL OR char_length(note) <= 500),
    reject_reason     text        CHECK (reject_reason IS NULL OR char_length(reject_reason) <= 500),
    paid_at           timestamptz,
    reviewed_by       uuid        REFERENCES users (id),
    reviewed_at       timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (period_id, slot_id, member_id),
    CHECK (status <> 'rejected' OR reject_reason IS NOT NULL),
    CHECK ((status = 'paid') = (paid_at IS NOT NULL))
);

CREATE INDEX payments_period_status_idx ON payments (period_id, status);
CREATE INDEX payments_member_status_idx ON payments (member_id, status);
CREATE INDEX payments_group_idx         ON payments (group_id);

CREATE TRIGGER payments_set_updated_at
    BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------- payment_proofs ----------

CREATE TABLE payment_proofs (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id    uuid        NOT NULL REFERENCES payments (id) ON DELETE CASCADE,
    object_key    text        NOT NULL,
    content_type  text        NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
    size_bytes    integer     NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 5242880),
    image_phash   bigint,
    uploaded_by   uuid        NOT NULL REFERENCES users (id),
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX payment_proofs_payment_idx ON payment_proofs (payment_id, created_at DESC);
CREATE INDEX payment_proofs_phash_idx   ON payment_proofs (image_phash) WHERE image_phash IS NOT NULL;

ALTER TABLE payments
    ADD CONSTRAINT payments_current_proof_fk
    FOREIGN KEY (current_proof_id) REFERENCES payment_proofs (id);

-- ---------- payouts ----------

CREATE TABLE payouts (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id         uuid        NOT NULL UNIQUE REFERENCES periods (id),
    winner_member_id  uuid        NOT NULL REFERENCES group_members (id),
    amount            bigint      NOT NULL CHECK (amount > 0),
    proof_key         text,
    note              text        CHECK (note IS NULL OR char_length(note) <= 500),
    recorded_by       uuid        NOT NULL REFERENCES users (id),
    recorded_at       timestamptz NOT NULL DEFAULT now(),
    confirmed_by      uuid        REFERENCES users (id),
    confirmed_at      timestamptz,
    CHECK ((confirmed_by IS NULL) = (confirmed_at IS NULL))
);

-- ---------- leave_requests ----------

CREATE TABLE leave_requests (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id     uuid        NOT NULL REFERENCES groups (id),
    member_id    uuid        NOT NULL REFERENCES group_members (id),
    reason       text        CHECK (reason IS NULL OR char_length(reason) <= 500),
    status       text        NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    reviewed_by  uuid        REFERENCES users (id),
    reviewed_at  timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX leave_requests_one_pending_uq
    ON leave_requests (member_id) WHERE status = 'pending';
CREATE INDEX leave_requests_group_idx ON leave_requests (group_id, status);

-- ---------- ownership_transfers ----------

CREATE TABLE ownership_transfers (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id      uuid        NOT NULL REFERENCES groups (id),
    from_user_id  uuid        NOT NULL REFERENCES users (id),
    to_member_id  uuid        NOT NULL REFERENCES group_members (id),
    status        text        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
    expires_at    timestamptz NOT NULL,
    responded_at  timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ownership_transfers_one_pending_uq
    ON ownership_transfers (group_id) WHERE status = 'pending';

-- ---------- activity_logs ----------

CREATE TABLE activity_logs (
    id             bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    group_id       uuid        NOT NULL REFERENCES groups (id),
    actor_type     text        NOT NULL DEFAULT 'user' CHECK (actor_type IN ('user', 'system')),
    actor_user_id  uuid        REFERENCES users (id),
    action         text        NOT NULL CHECK (action ~ '^[a-z_]+\.[a-z_]+$'),
    entity_type    text        NOT NULL,
    entity_id      uuid,
    before         jsonb,
    after          jsonb,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CHECK ((actor_type = 'user') = (actor_user_id IS NOT NULL))
);

CREATE INDEX activity_logs_group_cursor_idx ON activity_logs (group_id, id DESC);

CREATE TRIGGER activity_logs_append_only
    BEFORE UPDATE OR DELETE ON activity_logs
    FOR EACH ROW EXECUTE FUNCTION prevent_activity_log_change();

-- ---------- idempotency_keys ----------

CREATE TABLE idempotency_keys (
    user_id          uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    key              text        NOT NULL CHECK (char_length(key) BETWEEN 8 AND 100),
    method           text        NOT NULL,
    path             text        NOT NULL,
    request_hash     text        NOT NULL,
    response_status  smallint    NOT NULL,
    response_body    jsonb,
    created_at       timestamptz NOT NULL DEFAULT now(),
    expires_at       timestamptz NOT NULL DEFAULT now() + interval '24 hours',
    PRIMARY KEY (user_id, key)
);

CREATE INDEX idempotency_keys_expires_idx ON idempotency_keys (expires_at);

COMMIT;
