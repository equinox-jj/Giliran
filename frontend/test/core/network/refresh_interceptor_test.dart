import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/network/interceptors/auth_interceptor.dart';
import 'package:giliran/core/network/interceptors/refresh_interceptor.dart';
import 'package:giliran/core/network/session_manager.dart';
import 'package:giliran/core/storage/secure_storage.dart';

class _FakeStorage() implements SecureStorage {
  String? access = 'old';
  String? refresh = 'refresh-1';

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }

  // Not used by the interceptors.
  @override
  Future<String?> readPendingOtp() async => null;

  @override
  Future<void> savePendingOtp(String json) async {}

  @override
  Future<void> clearPendingOtp() async {}

  @override
  Future<String?> readCurrentUser() async => null;

  @override
  Future<void> saveCurrentUser(String json) async {}

  @override
  Future<void> clearCurrentUser() async {}
}

/// Answers `/auth/refresh` with [refreshStatus] and protected paths with 200
/// only for `Bearer new`; otherwise with [unauthorizedBody] as a 401.
class _FakeAdapter({
  final int refreshStatus = 200,
  final Map<String, Object?> unauthorizedBody = const {'status': 401, 'code': 'unauthorized'},
}) implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      // Let concurrent 401s queue up behind the in-flight refresh.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return refreshStatus == 200
          ? _json(200, {
              'data': {
                'access_token': 'new',
                'refresh_token': 'refresh-2',
                'token_type': 'Bearer',
                'expires_in': 900,
              },
            })
          : _json(refreshStatus, {
              'status': refreshStatus,
              'code': 'refresh_token_invalid',
            });
    }
    if (options.headers['Authorization'] == 'Bearer new') {
      return _json(200, {'data': 'ok'});
    }
    return _json(401, unauthorizedBody);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeStorage storage;
  late SessionManager sessionManager;

  setUp(() {
    storage = _FakeStorage();
    sessionManager = SessionManager();
  });

  tearDown(() => sessionManager.dispose());

  Dio buildDio(_FakeAdapter adapter) {
    Dio bare() => Dio()..httpClientAdapter = adapter;
    return bare()
      ..interceptors.addAll([
        AuthInterceptor(storage),
        RefreshInterceptor(
          storage: storage,
          sessionManager: sessionManager,
          refreshDio: bare(),
          retryDio: bare(),
        ),
      ]);
  }

  test('refreshes once for concurrent 401s and retries each request', () async {
    // Arrange
    final adapter = _FakeAdapter();
    final dio = buildDio(adapter);

    // Act
    final responses = await Future.wait([
      for (var i = 0; i < 3; i++) dio.get<Object?>('/groups'),
    ]);

    // Assert
    expect(adapter.refreshCalls, 1);
    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(storage.access, 'new');
    expect(storage.refresh, 'refresh-2');
  });

  test('retries a multipart upload with a fresh FormData', () async {
    // Arrange
    final adapter = _FakeAdapter();
    final dio = buildDio(adapter);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes([1, 2, 3], filename: 'a.jpg'),
    });

    // Act
    final response = await dio.put<Object?>('/me/avatar', data: form);

    // Assert
    expect(response.statusCode, 200);
    expect(adapter.refreshCalls, 1);
  });

  test('clears tokens and signals expiry when the refresh fails', () async {
    // Arrange
    final adapter = _FakeAdapter(refreshStatus: 401);
    final dio = buildDio(adapter);
    final expired = expectLater(sessionManager.onSessionExpired, emits(null));

    // Act
    final call = dio.get<Object?>('/groups');

    // Assert
    await expectLater(
      call,
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    await expired;
    expect(storage.access, isNull);
    expect(storage.refresh, isNull);
  });

  test('does not refresh on a business 401 such as pin_invalid', () async {
    // Arrange
    final adapter = _FakeAdapter(
      unauthorizedBody: const {'status': 401, 'code': 'pin_invalid'},
    );
    final dio = buildDio(adapter);

    // Act
    final call = dio.post<Object?>('/auth/pin/verify');

    // Assert
    await expectLater(call, throwsA(isA<DioException>()));
    expect(adapter.refreshCalls, 0);
    expect(storage.access, 'old');
  });
}
