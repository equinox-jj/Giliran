import 'package:dio/dio.dart';

import '../error/error_mapper.dart';
import '../error/exceptions.dart';

/// Mixed into remote data sources to centralize `DioException` →
/// [AppException] translation. Data sources call [safeApiCall] around each
/// request.
mixin BaseRemoteDataSource {
  /// Runs [request], translating any [DioException] into the matching
  /// [AppException]. [AppException]s thrown inside [request] pass through,
  /// [Error]s (programming bugs) are rethrown, and anything else becomes an
  /// [UnknownException].
  Future<T> safeApiCall<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e, st) {
      Error.throwWithStackTrace(mapDioException(e), st);
    } on AppException {
      rethrow;
    } on Error {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(UnknownException(e), st);
    }
  }
}
