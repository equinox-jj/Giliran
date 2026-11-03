import 'package:dio/dio.dart';

import '../../utils/logger/app_logger.dart';

/// Logs each request's method and URI, and each response's status code and
/// body, through [AppLogger]. Debug builds only: `DioClient` registers it
/// only when `kDebugMode` is true, and [AppLogger] is silent outside debug
/// builds anyway. Bodies are redacted by [AppLogger] (tokens, PINs, emails
/// and the like), and request headers are never logged.
class LoggerInterceptor() extends Interceptor {
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
      data: _loggableBody(response.data),
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
      data: _loggableBody(err.response?.data),
    );
    handler.next(err);
  }

  /// Keeps JSON and text bodies; drops bytes and streams (avatar uploads,
  /// downloads), which would only flood the console.
  static Object? _loggableBody(Object? body) => switch (body) {
    Map() || String() => body,
    List() when body is! List<int> => body,
    _ => null,
  };
}
