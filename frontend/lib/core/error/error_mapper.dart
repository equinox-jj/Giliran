import 'package:dio/dio.dart';

import '../logger/app_logger.dart';
import '../utils/enums/api_error_code.dart';
import 'exceptions.dart';
import 'failure.dart';
import 'problem_details.dart';

// Re-exported so callers that import only error_mapper.dart also get the
// Failure variants.
export 'failure.dart';

/// Converts a [DioException] into a typed [AppException].
AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutException();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const NetworkException();
    case DioExceptionType.cancel:
      return const RequestCancelledException();
    case DioExceptionType.badResponse:
      final response = e.response;
      if (response == null) return UnknownException(e);
      return _fromResponse(response);
    case DioExceptionType.unknown:
      final inner = e.error;
      if (inner is AppException) return inner;
      return UnknownException(inner ?? e);
  }
}

AppException _fromResponse(Response<dynamic> response) {
  final status = response.statusCode ?? 0;
  final data = response.data;
  final problem = data is Map<String, Object?> && data['code'] is String
      ? ProblemDetails.fromJson(data)
      : null;
  final retryAfter = _retryAfter(response.headers);

  return switch (status) {
    401 => UnauthorizedException(problem: problem),
    403 => ForbiddenException(problem: problem),
    404 => NotFoundException(problem: problem),
    409 => ConflictException(problem: problem),
    422 => ValidationException(problem: problem),
    429 => TooManyRequestsException(problem: problem, retryAfter: retryAfter),
    >= 500 => ServerException(
      status,
      problem: problem,
      retryAfter: retryAfter,
    ),
    >= 400 => BadRequestException(
      status,
      problem: problem,
      retryAfter: retryAfter,
    ),
    _ => UnknownException('Unexpected status $status'),
  };
}

/// Reads `Retry-After` as delay seconds; the HTTP-date form is not used by
/// the API.
Duration? _retryAfter(Headers headers) {
  final seconds = int.tryParse(headers.value('retry-after')?.trim() ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}

/// Converts any thrown error (typically an [AppException]) into a [Failure].
///
/// The API reuses some statuses for business rules (`pin_invalid` is a 401,
/// `otp_invalid` a 422), so 401 and 422 are refined by `code`. Errors the app
/// can't explain are logged so they aren't silent in debug builds.
Failure mapExceptionToFailure(Object error, [StackTrace? stackTrace]) {
  final failure = switch (error) {
    Failure() => error,
    NetworkException() => const Failure.network(),
    TimeoutException() => const Failure.timeout(),
    RequestCancelledException() => Failure.unknown(error, stackTrace),
    UnknownException(:final cause) => Failure.unknown(
      cause ?? error,
      stackTrace,
    ),
    CacheException(:final cause) => Failure.cache(cause),
    UnauthorizedException(:final code) when _isSessionError(code) =>
      Failure.unauthorized(
        code: code == ApiErrorCode.unknown ? ApiErrorCode.unauthorized : code,
        requestId: error.requestId,
      ),
    ValidationException(:final code)
        when code == ApiErrorCode.validationError ||
            code == ApiErrorCode.unknown =>
      Failure.validation(
        fieldErrors: error.fieldErrors,
        requestId: error.requestId,
      ),
    ForbiddenException() => Failure.forbidden(
      code: _codeOr(error, ApiErrorCode.forbiddenRole),
      requestId: error.requestId,
    ),
    NotFoundException() => Failure.notFound(
      code: _codeOr(error, ApiErrorCode.notFound),
      requestId: error.requestId,
    ),
    ConflictException() => Failure.conflict(
      code: error.code,
      requestId: error.requestId,
      extensions: error.problem?.extensions ?? const {},
    ),
    TooManyRequestsException() => Failure.tooManyRequests(
      code: _codeOr(error, ApiErrorCode.rateLimitExceeded),
      requestId: error.requestId,
      retryAfter: error.retryAfter,
    ),
    ServerException() => Failure.server(
      code: _codeOr(error, ApiErrorCode.internalError),
      status: error.statusCode,
      requestId: error.requestId,
      retryAfter: error.retryAfter,
    ),
    // 400, other 4xx, and 401/422 with a business code.
    ApiException() => Failure.badRequest(
      code: error.code,
      status: error.statusCode,
      requestId: error.requestId,
      retryAfter: error.retryAfter,
      extensions: error.problem?.extensions ?? const {},
    ),
    _ => Failure.unknown(error, stackTrace),
  };

  if (failure is UnknownFailure && error is! RequestCancelledException) {
    AppLogger.e(
      'Unexpected error in the data layer',
      tag: 'data',
      error: error,
      stackTrace: stackTrace,
    );
  }
  return failure;
}

bool _isSessionError(ApiErrorCode code) =>
    code == ApiErrorCode.unauthorized ||
    code == ApiErrorCode.refreshTokenInvalid ||
    code == ApiErrorCode.unknown;

ApiErrorCode _codeOr(ApiException e, ApiErrorCode fallback) =>
    e.code == ApiErrorCode.unknown ? fallback : e.code;
