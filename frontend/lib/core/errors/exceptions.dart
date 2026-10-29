import 'problem_details.dart';

/// Thrown by remote datasources when the API answers with Problem Details.
final class ServerException implements Exception {
  const ServerException(this.problem, {this.retryAfter});

  final ProblemDetails problem;

  /// From the `Retry-After` header on `429` and `423`.
  final Duration? retryAfter;

  @override
  String toString() =>
      'ServerException(${problem.status} ${problem.rawCode}, '
      'request_id: ${problem.requestId})';
}

/// Thrown when the request never got a response: no connection or a timeout.
final class NetworkException implements Exception {
  const NetworkException({this.timedOut = false});

  final bool timedOut;

  @override
  String toString() => 'NetworkException(timedOut: $timedOut)';
}

/// Thrown by local datasources when Drift, secure storage or shared
/// preferences fail, or when a required cached value is missing.
final class CacheException implements Exception {
  const CacheException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'CacheException($cause)';
}

/// Thrown when a success body does not match the expected model.
final class ParseException implements Exception {
  const ParseException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'ParseException($cause)';
}
