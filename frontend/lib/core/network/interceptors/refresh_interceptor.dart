import 'dart:async';

import 'package:dio/dio.dart';

import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';
import '../session_manager.dart';

/// Handles an expired access token (HTTP 401 `unauthorized`) by refreshing it
/// exactly once for any burst of concurrent failures (single-flight), then
/// retrying every queued request with the new token.
///
/// 401s with another `code`, such as `pin_invalid`, are business errors and
/// pass through untouched.
class RefreshInterceptor extends Interceptor {
  /// [refreshDio] and [retryDio] are bare Dio instances (no interceptors) so
  /// the refresh call and the replay can't recurse into this interceptor.
  RefreshInterceptor({
    required this._storage,
    required this._sessionManager,
    required this._refreshDio,
    required this._retryDio,
  });

  final SecureStorage _storage;
  final SessionManager _sessionManager;
  final Dio _refreshDio;
  final Dio _retryDio;

  /// Single-flight lock. Non-null while a refresh is in progress; completes
  /// with the new access token, or null if the refresh failed.
  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isNoAuth = options.extra[ApiEndpoints.kNoAuth] == true;
    final alreadyRetried = options.extra[ApiEndpoints.kRetried] == true;

    if (!_isExpiredSession(err.response) || isNoAuth || alreadyRetried) {
      handler.next(err);
      return;
    }

    final newToken = await _refreshToken();
    if (newToken == null) {
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _retry(options, newToken));
    } on DioException catch (e) {
      handler.next(e);
    } on Object catch (e, st) {
      handler.next(
        DioException(requestOptions: options, error: e, stackTrace: st),
      );
    }
  }

  /// A 401 whose body is missing or says `unauthorized`.
  bool _isExpiredSession(Response<dynamic>? response) {
    if (response?.statusCode != 401) return false;
    final data = response?.data;
    final code = data is Map ? data['code'] : null;
    return code == null || code == 'unauthorized';
  }

  /// Returns a fresh access token, performing at most one network refresh for
  /// concurrent callers. Returns null on failure.
  Future<String?> _refreshToken() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;
    unawaited(
      _performRefresh().then((token) {
        _refreshCompleter = null;
        completer.complete(token);
      }),
    );
    return completer.future;
  }

  Future<String?> _performRefresh() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _onRefreshFailed();
        return null;
      }

      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );
      final pair = response.data?['data'] as Map<String, dynamic>;
      final newAccess = pair['access_token'] as String;
      final newRefresh = pair['refresh_token'] as String;

      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return newAccess;
    } on Object {
      await _onRefreshFailed();
      return null;
    }
  }

  Future<void> _onRefreshFailed() async {
    try {
      await _storage.clearTokens();
    } finally {
      _sessionManager.notifyExpired();
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options, String newToken) {
    final headers = Map<String, dynamic>.of(options.headers)..['Authorization'] = 'Bearer $newToken';
    final extra = Map<String, dynamic>.of(options.extra)..[ApiEndpoints.kRetried] = true;
    return _retryDio.fetch<dynamic>(
      options.copyWith(headers: headers, extra: extra),
    );
  }
}
