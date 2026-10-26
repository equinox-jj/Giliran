BEGIN;

-- The draw seed exists from the moment a period opens (DB_SCHEME §5 step 1),
-- but periods.seed may only hold it once the result is stored
-- (CHECK seed IS NULL OR winner_slot_id IS NOT NULL). The sealed seed waits
-- here until the draw copies it into periods.seed, so nothing that reads
-- periods can reveal it early.
CREATE TABLE period_seeds (
    period_id   uuid        PRIMARY KEY REFERENCES periods (id),
    seed        text        NOT NULL CHECK (seed ~ '^[0-9a-f]{64}$'),
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION prevent_period_seed_change() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'period_seeds is immutable';
END;
$$ LANGUAGE plpgsql;

-- The published seed_hash commits to this seed, so it can never change.
CREATE TRIGGER period_seeds_immutable
    BEFORE UPDATE OR DELETE ON period_seeds
    FOR EACH ROW EXECUTE FUNCTION prevent_period_seed_change();

COMMIT;
