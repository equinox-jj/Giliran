BEGIN;

-- When an organizer last pushed a reminder for this payment, so a member gets
-- at most one manual reminder per period every 6 hours.
ALTER TABLE payments ADD COLUMN last_reminded_at timestamptz;

COMMIT;
