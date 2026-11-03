import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/idempotency_interceptor.dart';
import 'interceptors/logger_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';
import 'session_manager.dart';

part 'dio_client.g.dart';

/// Builds and owns the configured [Dio] instance used across the app.
class DioClient({
  required AuthInterceptor authInterceptor,
  required RefreshInterceptor refreshInterceptor,
  Dio? dio,
}) {
  this : dio = dio ?? Dio(baseOptions()) {
    this.dio.interceptors.addAll([
      IdempotencyInterceptor(),
      authInterceptor,
      refreshInterceptor,
      // Debug only: never log traffic in profile or release builds.
      if (kDebugMode) LoggerInterceptor(),
    ]);
  }

  /// The configured Dio instance.
  final Dio dio;

  /// Shared options: base URL, 15 s timeouts and JSON bodies.
  static BaseOptions baseOptions() => BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  );
}

/// The app-wide [Dio], with auth, refresh and logging interceptors.
///
/// Remote data sources take this through their own providers.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final storage = ref.watch(secureStorageProvider);
  final client = DioClient(
    authInterceptor: AuthInterceptor(storage),
    refreshInterceptor: RefreshInterceptor(
      storage: storage,
      sessionManager: ref.watch(sessionManagerProvider),
      refreshDio: Dio(DioClient.baseOptions()),
      retryDio: Dio(DioClient.baseOptions()),
    ),
  );
  ref.onDispose(client.dio.close);
  return client.dio;
}
