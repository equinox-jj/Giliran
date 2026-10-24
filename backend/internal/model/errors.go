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
	// Extensions are extra problem members, e.g. paid_count and total_count
	// on payments_incomplete.
	Extensions map[string]any
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

// WithExtensions returns a copy of e carrying ext as extra problem members.
func (e *Error) WithExtensions(ext map[string]any) *Error {
	c := *e
	c.Extensions = ext
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
	ErrValidation        = &Error{Kind: KindInvalid, Code: "validation_error", Message: "Request fields are invalid."}
	ErrBadRequest        = &Error{Kind: KindBadRequest, Code: "bad_request", Message: "The request is malformed."}
	ErrInvalidPagination = &Error{Kind: KindBadRequest, Code: "invalid_pagination", Message: "Pagination parameters are out of range."}

	ErrUnauthorized        = &Error{Kind: KindUnauthenticated, Code: "unauthorized", Message: "Missing, invalid or expired access token."}
	ErrOTPInvalid          = &Error{Kind: KindUnauthenticated, Code: "otp_invalid", Message: "The Firebase ID token was rejected."}
	ErrRefreshTokenInvalid = &Error{Kind: KindUnauthenticated, Code: "refresh_token_invalid", Message: "Refresh token is unknown, expired or revoked."}
	ErrPINInvalid          = &Error{Kind: KindUnauthenticated, Code: "pin_invalid", Message: "Wrong PIN."}
	ErrPINNotSet           = &Error{Kind: KindConflict, Code: "pin_not_set", Message: "This action requires a PIN that has not been set."}
	ErrPINLocked           = &Error{Kind: KindLocked, Code: "pin_locked", Message: "Too many wrong PIN attempts."}

	// ErrForbiddenRole is only for members whose role cannot do the action.
	// Non-members get ErrGroupNotFound instead, so group existence never leaks.
	ErrForbiddenRole = &Error{Kind: KindForbidden, Code: "forbidden_role", Message: "Your role in this group cannot do this."}

	// ErrNotFound is for unknown routes and wrong methods, not domain objects.
	ErrNotFound = &Error{Kind: KindNotFound, Code: "not_found", Message: "Resource not found."}

	ErrUserNotFound    = &Error{Kind: KindNotFound, Code: "user_not_found", Message: "User not found."}
	ErrGroupNotFound   = &Error{Kind: KindNotFound, Code: "group_not_found", Message: "Group not found."}
	ErrMemberNotFound  = &Error{Kind: KindNotFound, Code: "member_not_found", Message: "Member not found."}
	ErrPeriodNotFound  = &Error{Kind: KindNotFound, Code: "period_not_found", Message: "Period not found."}
	ErrPaymentNotFound = &Error{Kind: KindNotFound, Code: "payment_not_found", Message: "Payment not found."}
	ErrInviteNotFound  = &Error{Kind: KindNotFound, Code: "invite_not_found", Message: "Invite code is invalid or was reset."}
	ErrClaimNotFound   = &Error{Kind: KindNotFound, Code: "claim_not_found", Message: "Claim link is invalid or expired."}
	ErrDrawNotFound    = &Error{Kind: KindNotFound, Code: "draw_not_found", Message: "Verification code is unknown."}

	ErrPhoneAlreadyRegistered = &Error{Kind: KindConflict, Code: "phone_already_registered", Message: "This phone number already has an account."}
	ErrGroupFull              = &Error{Kind: KindConflict, Code: "group_full", Message: "The group has no free slots."}
	ErrGroupNotDraft          = &Error{Kind: KindConflict, Code: "group_not_draft", Message: "This setting can only change before the group starts."}
	ErrGroupNotActive         = &Error{Kind: KindConflict, Code: "group_not_active", Message: "The group is not running."}
	ErrAlreadyMember          = &Error{Kind: KindConflict, Code: "already_member", Message: "You are already in this group."}
	ErrFixedOrderIncomplete   = &Error{Kind: KindConflict, Code: "fixed_order_incomplete", Message: "Every slot needs a position before start."}
	ErrSlotsNotFilled         = &Error{Kind: KindConflict, Code: "slots_not_filled", Message: "Every slot needs a member before start."}
	ErrPaymentInfoMissing     = &Error{Kind: KindConflict, Code: "payment_info_missing", Message: "Organizer payment info is required before start."}
	ErrInvalidPaymentState    = &Error{Kind: KindConflict, Code: "invalid_payment_state", Message: "This payment status change is not allowed."}
	ErrPaymentAlreadyReviewed = &Error{Kind: KindConflict, Code: "payment_already_reviewed", Message: "The proof was already approved or rejected."}
	ErrPeriodNotOpen          = &Error{Kind: KindConflict, Code: "period_not_open", Message: "The period is not open for this action."}
	ErrDrawTooEarly           = &Error{Kind: KindConflict, Code: "draw_too_early", Message: "The draw date has not arrived."}
	ErrDrawAlreadyDone        = &Error{Kind: KindConflict, Code: "draw_already_done", Message: "This period has already been drawn."}
	ErrPaymentsIncomplete     = &Error{Kind: KindConflict, Code: "payments_incomplete", Message: "Not all payments are in; resend with confirm_incomplete: true."}
	ErrPayoutAlreadyRecorded  = &Error{Kind: KindConflict, Code: "payout_already_recorded", Message: "A payout is already recorded for this period."}
	ErrObligationsOutstanding = &Error{Kind: KindConflict, Code: "obligations_outstanding", Message: "Unpaid obligations block this action."}
	ErrOrganizerCannotLeave   = &Error{Kind: KindConflict, Code: "organizer_cannot_leave", Message: "Transfer ownership or close the group first."}
	ErrPendingRequestExists   = &Error{Kind: KindConflict, Code: "pending_request_exists", Message: "A pending leave request or transfer already exists."}

	ErrIdempotencyKeyReused = &Error{Kind: KindInvalid, Code: "idempotency_key_reused", Message: "The same Idempotency-Key was sent with a different request."}
	ErrFileTooLarge         = &Error{Kind: KindTooLarge, Code: "file_too_large", Message: "Upload is over 5 MB."}
	ErrUnsupportedMediaType = &Error{Kind: KindUnsupportedType, Code: "unsupported_media_type", Message: "Upload must be JPEG, PNG or WebP."}
	ErrRateLimitExceeded    = &Error{Kind: KindRateLimited, Code: "rate_limit_exceeded", Message: "Too many requests."}
	ErrInternal             = &Error{Kind: KindInternal, Code: "internal_error", Message: "Unexpected error."}
	ErrServiceUnavailable   = &Error{Kind: KindUnavailable, Code: "service_unavailable", Message: "Temporarily unavailable."}
)
