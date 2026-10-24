package model

import "fmt"

// ErrorKind classifies a domain error. pkg/response maps each kind to one HTTP
// status, so this package never imports net/http.
type ErrorKind int

const (
	KindInternal        ErrorKind = iota // 500
	KindBadRequest                       // 400
	KindUnauthenticated                  // 401
	KindForbidden                        // 403
	KindNotFound                         // 404
	KindConflict                         // 409
	KindTooLarge                         // 413
	KindUnsupportedType                  // 415
	KindInvalid                          // 422
	KindLocked                           // 423
	KindRateLimited                      // 429
	KindUnavailable                      // 503
)

// Error is a typed domain error carrying the stable `code` from the error
// table in api/api-spec.yaml. Services return the sentinels below (or a copy
// from WithDetail); pkg/response turns them into problem+json.
type Error struct {
	Kind    ErrorKind
	Code    string
	Message string // default human-readable detail; clients must not parse it
	Fields  []FieldError
}

func (e *Error) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// Is matches on Code, so errors.Is(err, ErrGroupNotFound) holds for wrapped
// errors and for copies made with WithDetail or NewValidationError.
func (e *Error) Is(target error) bool {
	t, ok := target.(*Error)
	return ok && t.Code == e.Code
}

// WithDetail returns a copy of e with a more specific message. Sentinels are
// shared, so never mutate them in place.
func (e *Error) WithDetail(format string, args ...any) *Error {
	c := *e
	c.Message = fmt.Sprintf(format, args...)
	return &c
}

// FieldCode is the machine-readable reason a single request field failed
// validation (FieldError.code in the API spec).
type FieldCode string

const (
	FieldRequired      FieldCode = "required"
	FieldInvalidFormat FieldCode = "invalid_format"
	FieldMinLength     FieldCode = "min_length"
	FieldMaxLength     FieldCode = "max_length"
	FieldMinimumValue  FieldCode = "minimum_value"
	FieldMaximumValue  FieldCode = "maximum_value"
	FieldInvalidChoice FieldCode = "invalid_choice"
	FieldDuplicate     FieldCode = "duplicate"
	FieldInvalidQRIS   FieldCode = "invalid_qris"
	FieldPINTooWeak    FieldCode = "pin_too_weak"
	FieldMismatch      FieldCode = "mismatch"
)

// FieldError is one entry of errors[] on a 422 validation_error. Field is the
// JSON path, e.g. "amount" or "order[2].position".
type FieldError struct {
	Field   string
	Code    FieldCode
	Message string
}

// NewValidationError returns a validation_error carrying fields.
func NewValidationError(fields ...FieldError) *Error {
	c := *ErrValidation
	c.Fields = fields
	return &c
}

// Sentinel errors, one per row of the error table in api/api-spec.yaml.
var (
	ErrValidation        = &Error{KindInvalid, "validation_error", "Request fields are invalid.", nil}
	ErrBadRequest        = &Error{KindBadRequest, "bad_request", "The request is malformed.", nil}
	ErrInvalidPagination = &Error{KindBadRequest, "invalid_pagination", "Pagination parameters are out of range.", nil}

	ErrUnauthorized        = &Error{KindUnauthenticated, "unauthorized", "Missing, invalid or expired access token.", nil}
	ErrOTPInvalid          = &Error{KindUnauthenticated, "otp_invalid", "The Firebase ID token was rejected.", nil}
	ErrRefreshTokenInvalid = &Error{KindUnauthenticated, "refresh_token_invalid", "Refresh token is unknown, expired or revoked.", nil}
	ErrPINInvalid          = &Error{KindUnauthenticated, "pin_invalid", "Wrong PIN.", nil}
	ErrPINNotSet           = &Error{KindConflict, "pin_not_set", "This action requires a PIN that has not been set.", nil}
	ErrPINLocked           = &Error{KindLocked, "pin_locked", "Too many wrong PIN attempts.", nil}

	// ErrForbiddenRole is only for members whose role cannot do the action.
	// Non-members get ErrGroupNotFound instead, so group existence never leaks.
	ErrForbiddenRole = &Error{KindForbidden, "forbidden_role", "Your role in this group cannot do this.", nil}

	ErrUserNotFound    = &Error{KindNotFound, "user_not_found", "User not found.", nil}
	ErrGroupNotFound   = &Error{KindNotFound, "group_not_found", "Group not found.", nil}
	ErrMemberNotFound  = &Error{KindNotFound, "member_not_found", "Member not found.", nil}
	ErrPeriodNotFound  = &Error{KindNotFound, "period_not_found", "Period not found.", nil}
	ErrPaymentNotFound = &Error{KindNotFound, "payment_not_found", "Payment not found.", nil}
	ErrInviteNotFound  = &Error{KindNotFound, "invite_not_found", "Invite code is invalid or was reset.", nil}
	ErrClaimNotFound   = &Error{KindNotFound, "claim_not_found", "Claim link is invalid or expired.", nil}
	ErrDrawNotFound    = &Error{KindNotFound, "draw_not_found", "Verification code is unknown.", nil}

	ErrPhoneAlreadyRegistered = &Error{KindConflict, "phone_already_registered", "This phone number already has an account.", nil}
	ErrGroupFull              = &Error{KindConflict, "group_full", "The group has no free slots.", nil}
	ErrGroupNotDraft          = &Error{KindConflict, "group_not_draft", "This setting can only change before the group starts.", nil}
	ErrGroupNotActive         = &Error{KindConflict, "group_not_active", "The group is not running.", nil}
	ErrAlreadyMember          = &Error{KindConflict, "already_member", "You are already in this group.", nil}
	ErrFixedOrderIncomplete   = &Error{KindConflict, "fixed_order_incomplete", "Every slot needs a position before start.", nil}
	ErrSlotsNotFilled         = &Error{KindConflict, "slots_not_filled", "Every slot needs a member before start.", nil}
	ErrPaymentInfoMissing     = &Error{KindConflict, "payment_info_missing", "Organizer payment info is required before start.", nil}
	ErrInvalidPaymentState    = &Error{KindConflict, "invalid_payment_state", "This payment status change is not allowed.", nil}
	ErrPaymentAlreadyReviewed = &Error{KindConflict, "payment_already_reviewed", "The proof was already approved or rejected.", nil}
	ErrPeriodNotOpen          = &Error{KindConflict, "period_not_open", "The period is not open for this action.", nil}
	ErrDrawTooEarly           = &Error{KindConflict, "draw_too_early", "The draw date has not arrived.", nil}
	ErrDrawAlreadyDone        = &Error{KindConflict, "draw_already_done", "This period has already been drawn.", nil}
	ErrPaymentsIncomplete     = &Error{KindConflict, "payments_incomplete", "Not all payments are in; resend with confirm_incomplete: true.", nil}
	ErrPayoutAlreadyRecorded  = &Error{KindConflict, "payout_already_recorded", "A payout is already recorded for this period.", nil}
	ErrObligationsOutstanding = &Error{KindConflict, "obligations_outstanding", "Unpaid obligations block this action.", nil}
	ErrOrganizerCannotLeave   = &Error{KindConflict, "organizer_cannot_leave", "Transfer ownership or close the group first.", nil}
	ErrPendingRequestExists   = &Error{KindConflict, "pending_request_exists", "A pending leave request or transfer already exists.", nil}

	ErrIdempotencyKeyReused = &Error{KindInvalid, "idempotency_key_reused", "The same Idempotency-Key was sent with a different request.", nil}
	ErrFileTooLarge         = &Error{KindTooLarge, "file_too_large", "Upload is over 5 MB.", nil}
	ErrUnsupportedMediaType = &Error{KindUnsupportedType, "unsupported_media_type", "Upload must be JPEG, PNG or WebP.", nil}
	ErrRateLimitExceeded    = &Error{KindRateLimited, "rate_limit_exceeded", "Too many requests.", nil}
	ErrInternal             = &Error{KindInternal, "internal_error", "Unexpected error.", nil}
	ErrServiceUnavailable   = &Error{KindUnavailable, "service_unavailable", "Temporarily unavailable.", nil}
)
