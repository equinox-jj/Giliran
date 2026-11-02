import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/data/base_local_data_source.dart';
import 'package:giliran/core/data/base_remote_data_source.dart';
import 'package:giliran/core/data/base_repository.dart';
import 'package:giliran/core/error/error_mapper.dart';
import 'package:giliran/core/error/exceptions.dart';

class _Remote() with BaseRemoteDataSource;

class _Local() with BaseLocalDataSource;

class _Repository() with BaseRepository;

void main() {
  final remote = _Remote();
  final local = _Local();
  final repository = _Repository();

  group('safeApiCall', () {
    test('maps a DioException to an AppException', () {
      // Arrange
      final error = DioException.connectionError(
        requestOptions: RequestOptions(path: '/me'),
        reason: 'offline',
      );

      // Act
      final call = remote.safeApiCall<void>(() async => throw error);

      // Assert
      expect(call, throwsA(isA<NetworkException>()));
    });

    test('passes an AppException through', () {
      // Act
      final call = remote.safeApiCall<void>(
        () async => throw const ForbiddenException(),
      );

      // Assert
      expect(call, throwsA(isA<ForbiddenException>()));
    });

    test('wraps other exceptions in UnknownException', () {
      // Act
      final call = remote.safeApiCall<void>(
        () async => throw const FormatException('bad'),
      );

      // Assert
      expect(call, throwsA(isA<UnknownException>()));
    });

    test('rethrows errors unmapped', () {
      // Act
      final call = remote.safeApiCall<void>(() async => throw StateError('x'));

      // Assert
      expect(call, throwsA(isA<StateError>()));
    });
  });

  group('safeCacheCall', () {
    test('wraps exceptions in CacheException', () {
      // Act
      final call = local.safeCacheCall<void>(
        () async => throw Exception('disk'),
      );

      // Assert
      expect(call, throwsA(isA<CacheException>()));
    });

    test('returns the value on success', () async {
      // Act
      final value = await local.safeCacheCall(() async => 'cached');

      // Assert
      expect(value, 'cached');
    });
  });

  group('safeCall', () {
    test('returns Right on success', () async {
      // Act
      final result = await repository.safeCall(() async => 42);

      // Assert
      expect(result, const Right<Failure, int>(42));
    });

    test('returns Left(Failure) on an exception', () async {
      // Act
      final result = await repository.safeCall<int>(
        () async => throw const NetworkException(),
      );

      // Assert
      expect(result, const Left<Failure, int>(Failure.network()));
    });

    test('rethrows errors', () {
      // Act
      final call = repository.safeCall<int>(() async => throw StateError('x'));

      // Assert
      expect(call, throwsA(isA<StateError>()));
    });
  });

  group('safeStream', () {
    test('emits values as Right and exceptions as Left', () {
      // Arrange
      Stream<int> source() async* {
        yield 1;
        throw const CacheException();
      }

      // Act
      final stream = repository.safeStream(source());

      // Assert
      expect(
        stream,
        emitsInOrder([
          const Right<Failure, int>(1),
          const Left<Failure, int>(Failure.cache()),
          emitsDone,
        ]),
      );
    });

    test('forwards errors as stream errors', () {
      // Act
      final stream = repository.safeStream(Stream<int>.error(StateError('x')));

      // Assert
      expect(stream, emitsError(isA<StateError>()));
    });
  });
}
