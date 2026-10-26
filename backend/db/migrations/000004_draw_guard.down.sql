BEGIN;

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

COMMIT;
