-- Email OTP requests (DB_SCHEME §3.16, §4.4). Times come from the caller's
-- clock. The 5-attempt and 5-resend limits are fixed by the table's CHECKs.

-- name: CancelPendingOtp :execrows
-- Runs before inserting a new request: one pending request per email and purpose.
UPDATE email_otp_requests SET status = 'cancelled'
WHERE email = sqlc.arg(email) AND purpose = sqlc.arg(purpose) AND status = 'pending';

-- name: CancelPendingOtpForUser :execrows
-- Account deletion: no code the user requested can complete afterwards.
UPDATE email_otp_requests SET status = 'cancelled'
WHERE user_id = sqlc.arg(user_id)::uuid AND status = 'pending';

-- name: CreateOtpRequest :one
INSERT INTO email_otp_requests (
    id, purpose, email, user_id, code_hash, send_status,
    device_name, device_platform, fcm_token, requester_ip,
    last_sent_at, expires_at, created_at
) VALUES (
    sqlc.arg(id), sqlc.arg(purpose), sqlc.arg(email), sqlc.narg(user_id), sqlc.arg(code_hash), sqlc.arg(send_status),
    sqlc.narg(device_name), sqlc.arg(device_platform), sqlc.narg(fcm_token), sqlc.narg(requester_ip),
    sqlc.arg(now)::timestamptz, sqlc.arg(expires_at)::timestamptz, sqlc.arg(now)::timestamptz
)
RETURNING *;

-- name: GetOtpRequest :one
-- Unlocked read for the email job.
SELECT * FROM email_otp_requests
WHERE id = $1;

-- name: GetOtpRequestForUpdate :one
-- Locks the row inside the resend and verify transactions.
SELECT * FROM email_otp_requests
WHERE id = $1
FOR UPDATE;

-- name: RecordOtpFailure :one
-- A wrong code; the fifth locks the request.
UPDATE email_otp_requests
SET attempts = attempts + 1,
    status   = CASE WHEN attempts + 1 >= 5 THEN 'locked' ELSE status END
WHERE id = sqlc.arg(id) AND status = 'pending'
RETURNING *;

-- name: ConsumeOtpRequest :one
-- In the same transaction as the session or change the code authorizes.
UPDATE email_otp_requests
SET status = 'consumed', consumed_at = sqlc.arg(now)::timestamptz, user_id = sqlc.arg(user_id)::uuid
WHERE id = sqlc.arg(id) AND status = 'pending'
RETURNING *;

-- name: ResendOtpRequest :one
-- A new code: attempts reset, expiry moves. A skipped request stays skipped,
-- since nothing is ever sent for it. No row when the request is no longer
-- pending, was last sent after sent_before, or has used its 5 resends.
UPDATE email_otp_requests
SET code_hash    = sqlc.arg(code_hash),
    attempts     = 0,
    resend_count = resend_count + 1,
    last_sent_at = sqlc.arg(now)::timestamptz,
    expires_at   = sqlc.arg(expires_at)::timestamptz,
    send_status  = CASE WHEN send_status = 'skipped' THEN 'skipped' ELSE 'queued' END,
    provider_message_id = NULL
WHERE id = sqlc.arg(id)
  AND status = 'pending'
  AND resend_count < 5
  AND last_sent_at <= sqlc.arg(sent_before)::timestamptz
RETURNING *;

-- name: MarkOtpSent :execrows
-- The email job's outcome. Matching resend_count keeps a job for an older code
-- from overwriting the status of a newer send.
UPDATE email_otp_requests
SET send_status = sqlc.arg(send_status), provider_message_id = sqlc.narg(provider_message_id)
WHERE id = sqlc.arg(id) AND resend_count = sqlc.arg(resend_count) AND send_status <> 'skipped';

-- name: ExpireOtpRequests :execrows
UPDATE email_otp_requests SET status = 'expired'
WHERE status = 'pending' AND expires_at <= sqlc.arg(now)::timestamptz;

-- name: CountRecentOtpByEmail :one
SELECT count(*) FROM email_otp_requests
WHERE email = sqlc.arg(email) AND created_at >= sqlc.arg(since)::timestamptz;

-- name: CountRecentOtpByIP :one
SELECT count(*) FROM email_otp_requests
WHERE requester_ip = sqlc.arg(requester_ip)::inet AND created_at >= sqlc.arg(since)::timestamptz;

-- name: DeleteOtpRequestsBefore :execrows
-- Retention (DB_SCHEME §10): any status, 24 hours after creation.
DELETE FROM email_otp_requests
WHERE created_at < sqlc.arg(before)::timestamptz;
