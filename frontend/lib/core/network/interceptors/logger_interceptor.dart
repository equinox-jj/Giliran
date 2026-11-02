import 'package:dio/dio.dart';

import '../../logger/app_logger.dart';

/// Logs each request's method, URI and status through [AppLogger], which is
/// silent outside debug builds. Bodies and headers are never logged.
class LoggerInterceptor extends Interceptor {
  static const _tag = 'http';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.d('→ ${options.method} ${options.uri}', tag: _tag);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    AppLogger.d(
      '← ${response.statusCode} ${request.method} ${request.uri}',
      tag: _tag,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    AppLogger.w(
      '✗ ${err.response?.statusCode ?? err.type.name} '
      '${request.method} ${request.uri}',
      tag: _tag,
    );
    handler.next(err);
  }
}
