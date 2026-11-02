import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/enums/api_error_code.dart';
import 'problem_details.dart';

part 'failure.freezed.dart';

/// A recoverable error as the domain and presentation layers see it,
/// returned inside `Either<Failure, T>`.
///
/// Consume with a Dart 3 `switch` over the sealed union. Failures carry codes
/// and data, never UI copy; `displayMessage` in `failure_message.dart` gives
/// the default Indonesian message and features override it per [apiCode].
@freezed
sealed class const Failure._() with _$Failure {
  /// No connection or a bad certificate. Shows the offline banner.
  const factory network() = NetworkFailure;

  /// A connect, send or receive timeout.
  const factory timeout() = TimeoutFailure;

  /// The API rejected the request for a reason the user can act on: HTTP
  /// 400, or any 4xx whose [code] is not a session, permission, not-found,
  /// conflict or field-validation error. Examples: `otp_invalid` (422),
  /// `pin_required` (422), `pin_invalid` (401), `otp_expired` (410),
  /// `pin_locked` (423), `file_too_large` (413). Branch on [code].
  const factory badRequest({
    required ApiErrorCode code,
    required int status,
    String? requestId,
    Duration? retryAfter,
    @Default(<String, Object?>{}) Map<String, Object?> extensions,
  }) = BadRequestFailure;

  /// `unauthorized` or `refresh_token_invalid`: the session is gone and the
  /// user must sign in again.
  const factory unauthorized({
    @Default(ApiErrorCode.unauthorized) ApiErrorCode code,
    String? requestId,
  }) = UnauthorizedFailure;

  /// HTTP 403, such as `forbidden_role`.
  const factory forbidden({
    @Default(ApiErrorCode.forbiddenRole) ApiErrorCode code,
    String? requestId,
  }) = ForbiddenFailure;

  /// HTTP 404, such as `group_not_found`.
  const factory notFound({
    @Default(ApiErrorCode.notFound) ApiErrorCode code,
    String? requestId,
  }) = NotFoundFailure;

  /// HTTP 409, such as `group_full` or `payments_incomplete`.
  const factory conflict({
    required ApiErrorCode code,
    String? requestId,
    @Default(<String, Object?>{}) Map<String, Object?> extensions,
  }) = ConflictFailure;

  /// `validation_error`: map [fieldErrors] to form fields by `field`.
  const factory validation({
    @Default(<FieldError>[]) List<FieldError> fieldErrors,
    String? requestId,
  }) = ValidationFailure;

  /// HTTP 429 (`rate_limit_exceeded`, `otp_too_many_attempts`).
  const factory tooManyRequests({
    @Default(ApiErrorCode.rateLimitExceeded) ApiErrorCode code,
    String? requestId,
    Duration? retryAfter,
  }) = TooManyRequestsFailure;

  /// HTTP 5xx.
  const factory server({
    @Default(ApiErrorCode.internalError) ApiErrorCode code,
    required int status,
    String? requestId,
    Duration? retryAfter,
  }) = ServerFailure;

  /// A local store (Drift, secure storage, shared preferences) failed.
  const factory cache([Object? cause]) = CacheFailure;

  /// Anything the mapper does not recognise, such as a malformed body or a
  /// cancelled request. Keeps the original error for crash reporting.
  const factory unknown([Object? cause, StackTrace? stackTrace]) = UnknownFailure;

  /// The Problem Details `code`, or null for failures that never reached the
  /// API.
  ApiErrorCode? get apiCode => switch (this) {
    BadRequestFailure(:final code) ||
    UnauthorizedFailure(:final code) ||
    ForbiddenFailure(:final code) ||
    NotFoundFailure(:final code) ||
    ConflictFailure(:final code) ||
    TooManyRequestsFailure(:final code) ||
    ServerFailure(:final code) => code,
    ValidationFailure() => ApiErrorCode.validationError,
    _ => null,
  };

  /// Correlation id shown in mono on the server-error card.
  String? get apiRequestId => switch (this) {
    BadRequestFailure(:final requestId) ||
    UnauthorizedFailure(:final requestId) ||
    ForbiddenFailure(:final requestId) ||
    NotFoundFailure(:final requestId) ||
    ConflictFailure(:final requestId) ||
    ValidationFailure(:final requestId) ||
    TooManyRequestsFailure(:final requestId) ||
    ServerFailure(:final requestId) => requestId,
    _ => null,
  };

  /// From `Retry-After` on `rate_limit_exceeded` or `pin_locked`.
  Duration? get retryAfterDelay => switch (this) {
    BadRequestFailure(:final retryAfter) ||
    TooManyRequestsFailure(:final retryAfter) ||
    ServerFailure(:final retryAfter) => retryAfter,
    _ => null,
  };

  /// Wrong OTP or PIN attempts left (`otp_invalid`, `pin_invalid`).
  int? get attemptsRemaining => switch (this) {
    BadRequestFailure(:final extensions) ||
    ConflictFailure(
      :final extensions,
    ) => (extensions['attempts_remaining'] as num?)?.toInt(),
    _ => null,
  };

  /// The server message for [field] on a [ValidationFailure], or null when
  /// the field is valid or this is another failure.
  String? fieldMessage(String field) {
    if (this case ValidationFailure(:final fieldErrors)) {
      for (final error in fieldErrors) {
        if (error.field == field) return error.message;
      }
    }
    return null;
  }
}
