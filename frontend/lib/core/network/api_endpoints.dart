/// Central registry of the API base URL, paths, and `RequestOptions.extra`
/// keys.
abstract final class ApiEndpoints() {
  /// Base URL for all requests. Override with
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1` android
  /// `--dart-define=API_BASE_URL=http://localhost:8080/api/v1` ios
  /// for a local backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://giliran.monai.my.id/api/v1',
  );

  /// Token refresh (`POST`, rotates the refresh token).
  static const String refresh = '/auth/refresh';

  /// Revokes the current session (`POST`).
  static const String logout = '/auth/logout';

  /// Set the PIN the first time (`POST`) or change it (`PUT`).
  static const String pin = '/auth/pin';

  /// Checks the PIN to unlock the app (`POST`).
  static const String pinVerify = '/auth/pin/verify';

  /// Requests a 6-digit email code (`POST`).
  static const String emailOtp = '/auth/email/otp';

  /// Sends a new code for the same request (`POST`).
  static String emailOtpResend(String otpId) => '/auth/email/otp/$otpId/resend';

  /// Verifies a code, with a PIN when the account needs one (`POST`).
  static String emailOtpVerify(String otpId) => '/auth/email/otp/$otpId/verify';

  /// The signed-in user's profile (`GET`, `PATCH`).
  static const String me = '/me';

  /// `extra` flag: skip attaching the access token (sign-in, refresh, public
  /// pages).
  static const String kNoAuth = 'noAuth';

  /// `extra` flag: request was already retried after a refresh.
  static const String kRetried = 'retried';
}
