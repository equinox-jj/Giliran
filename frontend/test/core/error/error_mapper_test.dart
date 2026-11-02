import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/error_mapper.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';

void main() {
  final options = RequestOptions(path: '/groups');

  DioException badResponse(
    int status,
    Object? data, {
    Map<String, List<String>> headers = const {},
  }) => DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );

  Failure mapDio(DioException e) => mapExceptionToFailure(mapDioException(e));

  group('mapDioException', () {
    test('maps timeouts to TimeoutException', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        // Arrange
        final error = DioException(requestOptions: options, type: type);

        // Act
        final result = mapDioException(error);

        // Assert
        expect(result, isA<TimeoutException>(), reason: type.name);
      }
    });

    test('maps connection errors to NetworkException', () {
      // Arrange
      final error = DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );

      // Act
      final result = mapDioException(error);

      // Assert
      expect(result, isA<NetworkException>());
    });

    test('maps a cancelled request to RequestCancelledException', () {
      // Arrange
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );

      // Act
      final result = mapDioException(error);

      // Assert
      expect(result, isA<RequestCancelledException>());
    });

    test('maps statuses to their ApiException types', () {
      final cases = <int, Matcher>{
        400: isA<BadRequestException>(),
        401: isA<UnauthorizedException>(),
        403: isA<ForbiddenException>(),
        404: isA<NotFoundException>(),
        409: isA<ConflictException>(),
        410: isA<BadRequestException>(),
        422: isA<ValidationException>(),
        423: isA<BadRequestException>(),
        429: isA<TooManyRequestsException>(),
        502: isA<ServerException>(),
      };
      for (final MapEntry(key: status, value: matcher) in cases.entries) {
        // Arrange
        final error = badResponse(status, {'code': 'x'});

        // Act
        final result = mapDioException(error);

        // Assert
        expect(result, matcher, reason: '$status');
        expect((result as ApiException).statusCode, status);
      }
    });

    test('parses the Problem Details body and Retry-After', () {
      // Arrange
      final error = badResponse(
        423,
        {'status': 423, 'code': 'pin_locked', 'request_id': 'req_1'},
        headers: {
          'retry-after': ['900'],
        },
      );

      // Act
      final result = mapDioException(error) as ApiException;

      // Assert
      expect(result.code, ApiErrorCode.pinLocked);
      expect(result.requestId, 'req_1');
      expect(result.retryAfter, const Duration(seconds: 900));
    });

    test('keeps no problem for a non-problem body', () {
      // Arrange
      final error = badResponse(502, '<html>Bad Gateway');

      // Act
      final result = mapDioException(error) as ApiException;

      // Assert
      expect(result.problem, isNull);
      expect(result.code, ApiErrorCode.unknown);
    });
  });

  group('mapExceptionToFailure', () {
    test('returns a Failure unchanged', () {
      // Arrange
      const failure = Failure.network();

      // Act
      final result = mapExceptionToFailure(failure);

      // Assert
      expect(result, same(failure));
    });

    test('maps network and timeout exceptions', () {
      // Act
      final network = mapExceptionToFailure(const NetworkException());
      final timeout = mapExceptionToFailure(const TimeoutException());

      // Assert
      expect(network, const Failure.network());
      expect(timeout, const Failure.timeout());
    });

    test('maps a validation problem to ValidationFailure', () {
      // Arrange
      final error = badResponse(422, {
        'status': 422,
        'code': 'validation_error',
        'request_id': 'req_1',
        'errors': [
          {'field': 'name', 'code': 'required', 'message': 'Wajib diisi.'},
        ],
      });

      // Act
      final failure = mapDio(error);

      // Assert
      expect(failure, isA<ValidationFailure>());
      expect(failure.apiRequestId, 'req_1');
      expect(failure.fieldMessage('name'), 'Wajib diisi.');
      expect(failure.fieldMessage('amount'), isNull);
    });

    test('maps a 422 business code to BadRequestFailure', () {
      // Arrange
      final error = badResponse(422, {
        'status': 422,
        'code': 'otp_invalid',
        'attempts_remaining': 3,
      });

      // Act
      final failure = mapDio(error);

      // Assert
      expect(failure, isA<BadRequestFailure>());
      expect(failure.apiCode, ApiErrorCode.otpInvalid);
      expect(failure.attemptsRemaining, 3);
    });

    test('maps session 401s to UnauthorizedFailure', () {
      // Arrange
      final refreshInvalid = badResponse(401, {
        'status': 401,
        'code': 'refresh_token_invalid',
      });
      final noBody = badResponse(401, null);

      // Act
      final first = mapDio(refreshInvalid);
      final second = mapDio(noBody);

      // Assert
      expect(
        first,
        const Failure.unauthorized(code: ApiErrorCode.refreshTokenInvalid),
      );
      expect(second, const Failure.unauthorized());
    });

    test('maps pin_invalid 401 to BadRequestFailure, not a lost session', () {
      // Arrange
      final error = badResponse(401, {'status': 401, 'code': 'pin_invalid'});

      // Act
      final failure = mapDio(error);

      // Assert
      expect(failure, isA<BadRequestFailure>());
      expect(failure.apiCode, ApiErrorCode.pinInvalid);
    });

    test('maps 409 to ConflictFailure with extensions', () {
      // Arrange
      final error = badResponse(409, {
        'status': 409,
        'code': 'payments_incomplete',
        'paid_count': 3,
      });

      // Act
      final failure = mapDio(error);

      // Assert
      expect(
        failure,
        const Failure.conflict(
          code: ApiErrorCode.paymentsIncomplete,
          extensions: {'paid_count': 3},
        ),
      );
    });

    test('maps 429 to TooManyRequestsFailure with Retry-After', () {
      // Arrange
      final error = badResponse(
        429,
        {'status': 429, 'code': 'rate_limit_exceeded'},
        headers: {
          'retry-after': ['750'],
        },
      );

      // Act
      final failure = mapDio(error);

      // Assert
      expect(failure, isA<TooManyRequestsFailure>());
      expect(failure.retryAfterDelay, const Duration(seconds: 750));
    });

    test('maps a non-problem 5xx to ServerFailure', () {
      // Arrange
      final error = badResponse(502, '<html>Bad Gateway');

      // Act
      final failure = mapDio(error);

      // Assert
      expect(failure, const Failure.server(status: 502));
    });

    test('maps CacheException to CacheFailure', () {
      // Act
      final failure = mapExceptionToFailure(const CacheException('miss'));

      // Assert
      expect(failure, const Failure.cache('miss'));
    });

    test('maps cancelled requests and anything else to UnknownFailure', () {
      // Act
      final cancelled = mapExceptionToFailure(
        const RequestCancelledException(),
      );
      final other = mapExceptionToFailure(const FormatException('bad'));

      // Assert
      expect(cancelled, isA<UnknownFailure>());
      expect(other, isA<UnknownFailure>());
    });
  });

  test('maps a NotFoundException built from ProblemDetails', () {
    // Arrange
    final problem = ProblemDetails.fromJson({
      'status': 404,
      'code': 'group_not_found',
    });

    // Act
    final failure = mapExceptionToFailure(NotFoundException(problem: problem));

    // Assert
    expect(failure, const Failure.notFound(code: ApiErrorCode.groupNotFound));
  });
}
