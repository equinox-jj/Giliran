import '../error/exceptions.dart';

/// Mixed into local data sources to centralize cache-error translation.
/// Wraps each local operation, converting any failure into [CacheException].
mixin BaseLocalDataSource {
  /// Runs [op]; any exception becomes a [CacheException]. An already-typed
  /// [CacheException] and [Error]s (programming bugs) pass through unchanged.
  Future<T> safeCacheCall<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on CacheException {
      rethrow;
    } on Error {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(CacheException(e), st);
    }
  }
}
