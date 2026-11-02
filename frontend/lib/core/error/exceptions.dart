import '../utils/enums/api_error_code.dart';
import 'problem_details.dart';

/// Typed exceptions thrown in the data layer.
///
/// Mapped from `DioException` by `error_mapper.dart` and converted to a
/// `Failure` at the repository boundary.
sealed class const AppException() implements Exception;

/// No connection, a socket error or a bad certificate.
final class const NetworkException() extends AppException {
  @override
  String toString() => 'NetworkException()';
}

/// The request exceeded a configured timeout.
final class const TimeoutException() extends AppException {
  @override
  String toString() => 'TimeoutException()';
}

/// The request was cancelled through its `CancelToken`.
final class const RequestCancelledException() extends AppException {
  @override
  String toString() => 'RequestCancelledException()';
}

/// Anything not otherwise classified, such as a malformed body.
final class const UnknownException([final Object? cause]) extends AppException {
  @override
  String toString() => 'UnknownException($cause)';
}

/// Drift, secure storage or shared preferences failed, or a required cached
/// value is missing.
final class const CacheException([final Object? cause]) extends AppException {
  @override
  String toString() => 'CacheException($cause)';
}

/// The API answered with an error status.
///
/// [problem] is the RFC 9457 body when the API sent one. Branch on [code],
/// never on `detail`.
sealed class const ApiException(
  final int statusCode, {
  final ProblemDetails? problem,

  /// From the `Retry-After` header on `429` and `423`.
  final Duration? retryAfter,
}) extends AppException {
  ApiErrorCode get code => problem?.code ?? ApiErrorCode.unknown;

  /// Correlation id shown on the server-error card for support.
  String? get requestId => problem?.requestId;

  @override
  String toString() => '$runtimeType($statusCode ${problem?.rawCode}, request_id: $requestId)';
}

/// HTTP 400, and any 4xx without its own type (413, 415, 423, …).
final class const BadRequestException(
  super.statusCode, {
  super.problem,
  super.retryAfter,
}) extends ApiException;

/// HTTP 401: the session is gone because the refresh already failed, or a
/// business error such as `pin_invalid`.
final class const UnauthorizedException({super.problem}) extends ApiException {
  this : super(401);
}

/// HTTP 403.
final class const ForbiddenException({super.problem}) extends ApiException {
  this : super(403);
}

/// HTTP 404.
final class const NotFoundException({super.problem}) extends ApiException {
  this : super(404);
}

/// HTTP 409, such as `group_full` or `already_member`.
final class const ConflictException({super.problem}) extends ApiException {
  this : super(409);
}

/// HTTP 422. Holds [fieldErrors], keyed by JSON path, for `validation_error`;
/// business codes such as `otp_invalid` arrive here too.
final class const ValidationException({super.problem}) extends ApiException {
  this : super(422);

  List<FieldError> get fieldErrors => problem?.fieldErrors ?? const [];
}

/// HTTP 429.
final class const TooManyRequestsException({super.problem, super.retryAfter}) extends ApiException {
  this : super(429);
}

/// HTTP 5xx.
final class const ServerException(
  super.statusCode, {
  super.problem,
  super.retryAfter,
}) extends ApiException;
