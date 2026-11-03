import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/network/api_endpoints.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/network/interceptors/idempotency_interceptor.dart';

/// Records each request and answers 200 with an empty JSON object.
class _RecordingAdapter() implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(IdempotencyInterceptor());
  });

  group('IdempotencyInterceptor', () {
    test('sends the extra key as the Idempotency-Key header', () async {
      // Arrange
      final options = Options(extra: {ApiEndpoints.kIdempotencyKey: 'k1'});

      // Act
      await dio.post<void>('/payments', options: options);

      // Assert
      expect(adapter.requests.single.headers['Idempotency-Key'], 'k1');
    });

    test('adds no header when the request has no key', () async {
      // Arrange
      const path = '/me';

      // Act
      await dio.get<void>(path);

      // Assert
      expect(adapter.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('a retry with the same key sends the same header', () async {
      // Arrange
      final key = IdempotencyKey.generate();
      final options = Options(extra: {ApiEndpoints.kIdempotencyKey: key.value});

      // Act
      await dio.post<void>('/draw', options: options);
      await dio.post<void>('/draw', options: options);

      // Assert
      final sent = adapter.requests.map((r) => r.headers['Idempotency-Key']).toList();
      expect(sent, [key.value, key.value]);
    });
  });

  group('IdempotencyKey.generate', () {
    test('returns distinct UUID v4 strings', () {
      // Arrange
      final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

      // Act
      final a = IdempotencyKey.generate();
      final b = IdempotencyKey.generate();

      // Assert
      expect(a.value, matches(v4));
      expect(b.value, matches(v4));
      expect(a, isNot(b));
    });
  });
}
