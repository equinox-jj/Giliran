import 'package:equatable/equatable.dart';

import '../utils/enums/api_error_code.dart';
import 'problem_details.dart';

/// A recoverable error as the domain and presentation layers see it.
///
/// Repositories throw only [Failure]s (see `guard` in `exception_mapper.dart`),
/// so controllers receive them as `AsyncValue.error` and `switch` over the
/// sealed family. Failures carry codes and data, never UI copy; presentation
/// picks the Indonesian message.
sealed class Failure extends Equatable implements Exception {
  const Failure();
}

/// No connection or a timeout. Shows the offline banner or "Coba lagi".
final class NetworkFailure extends Failure {
  const NetworkFailure({this.timedOut = false});

  final bool timedOut;

  @override
  List<Object?> get props => [timedOut];
}

/// The API rejected the request. Branch on [code].
///
/// [ValidationFailure] and [UnauthorizedFailure] refine the codes the app
/// handles generically.
class ServerFailure extends Failure {
  const ServerFailure({
    required this.code,
    required this.status,
    this.rawCode,
    this.requestId,
    this.detail,
    this.extensions = const {},
    this.retryAfter,
  });

  ServerFailure.fromProblem(ProblemDetails problem, {Duration? retryAfter})
    : this(
        code: problem.code,
        status: problem.status,
        rawCode: problem.rawCode,
        requestId: problem.requestId,
        detail: problem.detail,
        extensions: problem.extensions,
        retryAfter: retryAfter,
      );

  final ApiErrorCode code;
  final int status;

  /// The `code` as sent, useful when [code] is [ApiErrorCode.unknown].
  final String? rawCode;

  /// Shown in mono on the server-error card for support.
  final String? requestId;

  /// For logs only; never shown or parsed.
  final String? detail;

  /// Extra problem members such as `attempts_remaining`.
  final Map<String, Object?> extensions;

  /// From `Retry-After` on `rate_limit_exceeded` or `pin_locked`.
  final Duration? retryAfter;

  int? get attemptsRemaining =>
      (extensions['attempts_remaining'] as num?)?.toInt();

  @override
  List<Object?> get props => [
    code,
    status,
    rawCode,
    requestId,
    detail,
    extensions,
    retryAfter,
  ];
}

/// `validation_error`: map [fieldErrors] to form fields by `field`.
final class ValidationFailure extends ServerFailure {
  ValidationFailure.fromProblem(super.problem)
    : fieldErrors = problem.fieldErrors,
      super.fromProblem();

  const ValidationFailure({
    required this.fieldErrors,
    super.status = 422,
    super.requestId,
    super.detail,
  }) : super(code: ApiErrorCode.validationError);

  final List<FieldError> fieldErrors;

  /// The server message for [field], or null when the field is valid.
  String? messageFor(String field) {
    for (final error in fieldErrors) {
      if (error.field == field) return error.message;
    }
    return null;
  }

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// `unauthorized` or `refresh_token_invalid`: the session is gone and the
/// user must sign in again.
final class UnauthorizedFailure extends ServerFailure {
  UnauthorizedFailure.fromProblem(super.problem) : super.fromProblem();

  const UnauthorizedFailure({
    super.code = ApiErrorCode.unauthorized,
    super.requestId,
    super.detail,
  }) : super(status: 401);
}

/// A local store (Drift, secure storage, shared preferences) failed.
final class CacheFailure extends Failure {
  const CacheFailure([this.cause]);

  final Object? cause;

  @override
  List<Object?> get props => [cause];
}

/// Anything the mapper does not recognise, such as a malformed body or a
/// cancelled request. Keeps the original error for crash reporting.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [error];
}
