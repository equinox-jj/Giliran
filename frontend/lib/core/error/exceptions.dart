import '../utils/enums/api_error_code.dart';
import 'problem_details.dart';

/// Typed exceptions thrown in the data layer.
///
/// Mapped from `DioException` by `error_mapper.dart` and converted to a
/// `Failure` at the repository boundary.
sealed class AppException implements Exception {
  const AppException();
}

/// No connection, a socket error or a bad certificate.
final class NetworkException extends AppException {
  const NetworkException();

  @override
  String toString() => 'NetworkException()';
}

/// The request exceeded a configured timeout.
final class TimeoutException extends AppException {
  const TimeoutException();

  @override
  String toString() => 'TimeoutException()';
}

/// The request was cancelled through its `CancelToken`.
final class RequestCancelledException extends AppException {
  const RequestCancelledException();

  @override
  String toString() => 'RequestCancelledException()';
}

/// Anything not otherwise classified, such as a malformed body.
final class UnknownException extends AppException {
  const UnknownException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'UnknownException($cause)';
}

/// Drift, secure storage or shared preferences failed, or a required cached
/// value is missing.
final class CacheException extends AppException {
  const CacheException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'CacheException($cause)';
}

/// The API answered with an error status.
///
/// [problem] is the RFC 9457 body when the API sent one. Branch on [code],
/// never on `detail`.
sealed class ApiException extends AppException {
  const ApiException(this.statusCode, {this.problem, this.retryAfter});

  final int statusCode;
  final ProblemDetails? problem;

  /// From the `Retry-After` header on `429` and `423`.
  final Duration? retryAfter;

  ApiErrorCode get code => problem?.code ?? ApiErrorCode.unknown;

  /// Correlation id shown on the server-error card for support.
  String? get requestId => problem?.requestId;

  @override
  String toString() => '$runtimeType($statusCode ${problem?.rawCode}, request_id: $requestId)';
}

/// HTTP 400, and any 4xx without its own type (413, 415, 423, …).
final class BadRequestException extends ApiException {
  const BadRequestException(
    super.statusCode, {
    super.problem,
    super.retryAfter,
  });
}

/// HTTP 401: the session is gone because the refresh already failed, or a
/// business error such as `pin_invalid`.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException({super.problem}) : super(401);
}

/// HTTP 403.
final class ForbiddenException extends ApiException {
  const ForbiddenException({super.problem}) : super(403);
}

/// HTTP 404.
final class NotFoundException extends ApiException {
  const NotFoundException({super.problem}) : super(404);
}

/// HTTP 409, such as `group_full` or `already_member`.
final class ConflictException extends ApiException {
  const ConflictException({super.problem}) : super(409);
}

/// HTTP 422. Holds [fieldErrors], keyed by JSON path, for `validation_error`;
/// business codes such as `otp_invalid` arrive here too.
final class ValidationException extends ApiException {
  const ValidationException({super.problem}) : super(422);

  List<FieldError> get fieldErrors => problem?.fieldErrors ?? const [];
}

/// HTTP 429.
final class TooManyRequestsException extends ApiException {
  const TooManyRequestsException({super.problem, super.retryAfter}) : super(429);
}

/// HTTP 5xx.
final class ServerException extends ApiException {
  const ServerException(
    super.statusCode, {
    super.problem,
    super.retryAfter,
  });
}
