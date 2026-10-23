BEGIN;

DROP TABLE IF EXISTS idempotency_keys;
DROP TABLE IF EXISTS activity_logs;
DROP TABLE IF EXISTS ownership_transfers;
DROP TABLE IF EXISTS leave_requests;
DROP TABLE IF EXISTS payouts;
-- payments and payment_proofs reference each other, so drop them together
DROP TABLE IF EXISTS payments, payment_proofs;
DROP TABLE IF EXISTS periods;
DROP TABLE IF EXISTS slot_members;
DROP TABLE IF EXISTS slots;
DROP TABLE IF EXISTS group_members;
DROP TABLE IF EXISTS groups;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS users;

DROP FUNCTION IF EXISTS guard_period_draw();
DROP FUNCTION IF EXISTS prevent_activity_log_change();
DROP FUNCTION IF EXISTS set_updated_at();

COMMIT;
