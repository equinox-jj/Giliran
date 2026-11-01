import 'package:dio/dio.dart';

import '../logger/app_logger.dart';
import '../utils/enums/api_error_code.dart';
import 'exceptions.dart';
import 'failures.dart';
import 'problem_details.dart';

/// Runs [body] and rethrows any exception as a [Failure].
///`
/// Repository impls wrap each datasource call in this so the domain and
/// presentation layers only ever see [Failure]s.
Future<T> guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on Error {
    rethrow;
  } on Object catch (e, st) {
    Error.throwWithStackTrace(_mapAndLog(e, st), st);
  }
}

/// Like [guard], for streams such as Drift watch queries.
Stream<T> guardStream<T>(Stream<T> stream) => stream.handleError(
  (Object e, StackTrace st) => Error.throwWithStackTrace(_mapAndLog(e, st), st),
  test: (e) => e is! Error,
);

/// Converts anything a datasource can throw into a [Failure].
///
/// [Error]s are programming bugs and must not reach here; [guard] rethrows
/// them before calling this.
Failure mapToFailure(Object error, [StackTrace? stackTrace]) => switch (error) {
  Failure() => error,
  ServerException(:final problem, :final retryAfter) => _fromProblem(
    problem,
    retryAfter: retryAfter,
  ),
  NetworkException(:final timedOut) => NetworkFailure(timedOut: timedOut),
  CacheException(:final cause) => CacheFailure(cause),
  DioException() => _fromDio(error, stackTrace),
  _ => UnexpectedFailure(error, stackTrace),
};

/// Maps like [mapToFailure], logging failures the app can't explain so they
/// aren't silent in debug builds.
Failure _mapAndLog(Object error, StackTrace stackTrace) {
  final failure = mapToFailure(error, stackTrace);
  if (failure is UnexpectedFailure) {
    AppLogger.e(
      'Unexpected error in the data layer',
      tag: 'data',
      error: failure,
      stackTrace: stackTrace,
    );
  }

  return failure;
}

Failure _fromDio(DioException e, StackTrace? stackTrace) {
  switch (e.type) {
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkFailure(timedOut: true);
    case DioExceptionType.badResponse:
      final response = e.response;
      if (response == null) return UnexpectedFailure(e, stackTrace);

      final retryAfter = _retryAfter(response.headers);
      final data = response.data;
      if (data is Map<String, Object?> && data['code'] is String) {
        return _fromProblem(
          ProblemDetails.fromJson(data),
          retryAfter: retryAfter,
        );
      }

      final status = response.statusCode ?? 0;

      return status == 401
          ? const UnauthorizedFailure()
          : ServerFailure(
              code: ApiErrorCode.unknown,
              status: status,
              retryAfter: retryAfter,
            );
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      final inner = e.error;
      if (inner is Exception && inner is! DioException) {
        return mapToFailure(inner, stackTrace);
      }

      return UnexpectedFailure(e, stackTrace);
  }
}

Failure _fromProblem(
  ProblemDetails problem, {
  Duration? retryAfter,
}) => switch (problem.code) {
  ApiErrorCode.validationError => ValidationFailure.fromProblem(problem),
  ApiErrorCode.unauthorized ||
  ApiErrorCode.refreshTokenInvalid => UnauthorizedFailure.fromProblem(
    problem,
  ),
  _ => ServerFailure.fromProblem(problem, retryAfter: retryAfter),
};

/// Reads `Retry-After` as delay seconds; the HTTP-date form is not used by
/// the API.
Duration? _retryAfter(Headers headers) {
  final seconds = int.tryParse(headers.value('retry-after')?.trim() ?? '');

  return seconds == null ? null : Duration(seconds: seconds);
}
