import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/errors/errors.dart';
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

  group('mapToFailure', () {
    test('returns a Failure unchanged', () {
      const failure = NetworkFailure();
      expect(mapToFailure(failure), same(failure));
    });

    test('maps connection errors and timeouts to NetworkFailure', () {
      expect(
        mapToFailure(
          DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
        const NetworkFailure(),
      );
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          mapToFailure(DioException(requestOptions: options, type: type)),
          const NetworkFailure(timedOut: true),
        );
      }
    });

    test('maps a validation problem to ValidationFailure', () {
      final failure = mapToFailure(
        badResponse(422, {
          'status': 422,
          'code': 'validation_error',
          'request_id': 'req_1',
          'errors': [
            {'field': 'name', 'code': 'required', 'message': 'Wajib diisi.'},
          ],
        }),
      );

      expect(failure, isA<ValidationFailure>());
      failure as ValidationFailure;
      expect(failure.requestId, 'req_1');
      expect(failure.messageFor('name'), 'Wajib diisi.');
      expect(failure.messageFor('amount'), isNull);
    });

    test('maps unauthorized codes to UnauthorizedFailure', () {
      final failure = mapToFailure(
        badResponse(401, {'status': 401, 'code': 'refresh_token_invalid'}),
      );

      expect(failure, isA<UnauthorizedFailure>());
      expect(
        (failure as UnauthorizedFailure).code,
        ApiErrorCode.refreshTokenInvalid,
      );
    });

    test('maps other problems to ServerFailure with Retry-After', () {
      final failure = mapToFailure(
        badResponse(
          429,
          {'status': 429, 'code': 'rate_limit_exceeded'},
          headers: {
            'retry-after': ['750'],
          },
        ),
      );

      expect(failure, isA<ServerFailure>());
      failure as ServerFailure;
      expect(failure.code, ApiErrorCode.rateLimitExceeded);
      expect(failure.retryAfter, const Duration(seconds: 750));
    });

    test('maps a non-problem body to an unknown ServerFailure', () {
      final failure = mapToFailure(badResponse(502, '<html>Bad Gateway'));

      expect(
        failure,
        const ServerFailure(code: ApiErrorCode.unknown, status: 502),
      );
    });

    test('maps data-layer exceptions', () {
      expect(
        mapToFailure(const NetworkException(timedOut: true)),
        const NetworkFailure(timedOut: true),
      );
      expect(
        mapToFailure(const CacheException('miss')),
        const CacheFailure('miss'),
      );
      expect(
        mapToFailure(
          ServerException(
            ProblemDetails.fromJson({'status': 409, 'code': 'group_full'}),
          ),
        ),
        isA<ServerFailure>().having(
          (f) => f.code,
          'code',
          ApiErrorCode.groupFull,
        ),
      );
    });

    test('maps a cancelled request and anything else to UnexpectedFailure', () {
      expect(
        mapToFailure(
          DioException(requestOptions: options, type: DioExceptionType.cancel),
        ),
        isA<UnexpectedFailure>(),
      );
      expect(
        mapToFailure(const FormatException('bad')),
        isA<UnexpectedFailure>(),
      );
    });
  });

  group('guard', () {
    test('rethrows exceptions as failures', () {
      expect(
        guard<void>(() async => throw const NetworkException()),
        throwsA(const NetworkFailure()),
      );
    });

    test('lets errors through unmapped', () {
      expect(
        guard<void>(() async => throw StateError('bug')),
        throwsA(isA<StateError>()),
      );
    });

    test('returns the value on success', () async {
      expect(await guard(() async => 42), 42);
    });
  });

  group('guardStream', () {
    test('maps stream errors to failures', () {
      final stream = guardStream(Stream<int>.error(const CacheException()));
      expect(stream, emitsError(const CacheFailure()));
    });
  });
}
