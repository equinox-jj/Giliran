import 'package:dio/dio.dart';

import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';

/// Attaches `Authorization: Bearer <access token>` to every request unless it
/// is flagged [ApiEndpoints.kNoAuth].
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final noAuth = options.extra[ApiEndpoints.kNoAuth] == true;
    if (!noAuth) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}
