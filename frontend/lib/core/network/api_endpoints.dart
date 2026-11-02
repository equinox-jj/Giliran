/// Central registry of the API base URL, paths, and `RequestOptions.extra`
/// keys.
abstract final class ApiEndpoints {
  /// Base URL for all requests. Override with
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1` for a local
  /// backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://giliran.monai.my.id/api/v1',
  );

  /// Token refresh (`POST`, rotates the refresh token).
  static const String refresh = '/auth/refresh';

  /// `extra` flag: skip attaching the access token (sign-in, refresh, public
  /// pages).
  static const String kNoAuth = 'noAuth';

  /// `extra` flag: request was already retried after a refresh.
  static const String kRetried = 'retried';
}
