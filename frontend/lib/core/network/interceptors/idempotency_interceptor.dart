import 'package:dio/dio.dart';

import '../api_endpoints.dart';

/// Sends `extra[ApiEndpoints.kIdempotencyKey]` as the `Idempotency-Key` header.
class IdempotencyInterceptor() extends Interceptor {
  static const header = 'Idempotency-Key';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = options.extra[ApiEndpoints.kIdempotencyKey];
    if (key is String && key.isNotEmpty) options.headers[header] = key;
    handler.next(options);
  }
}
