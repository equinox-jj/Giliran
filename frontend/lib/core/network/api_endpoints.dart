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

  /// The signed-in user's profile picture (`PUT` multipart, `DELETE`).
  static const String meAvatar = '/me/avatar';

  /// Deletes the signed-in account with the PIN (`POST`).
  static const String meDeletion = '/me/deletion';

  /// Notification and language settings (`GET`, `PATCH`).
  static const String meSettings = '/me/settings';

  /// Active sessions, current one first (`GET`).
  static const String meSessions = '/me/sessions';

  /// Signs out one other device (`DELETE`).
  static String meSession(String sessionId) => '/me/sessions/$sessionId';

  /// Groups I organize or belong to (`GET`, `?status=active|finished|all`).
  static const String meGroups = '/me/groups';

  /// Creates a group (`POST`).
  static const String groups = '/groups';

  /// One group (`GET`, `PATCH`).
  static String group(String groupId) => '/groups/$groupId';

  /// Closes a group for good (`POST`).
  static String groupClose(String groupId) => '/groups/$groupId/close';

  /// The organizer's bank account (`PUT`).
  static String paymentInfo(String groupId) => '/groups/$groupId/payment-info';

  /// The organizer's QRIS image (`PUT` multipart, `DELETE`).
  static String paymentInfoQris(String groupId) => '/groups/$groupId/payment-info/qris';

  /// `extra` flag: skip attaching the access token (sign-in, refresh, public
  /// pages).
  static const String kNoAuth = 'noAuth';

  /// `extra` flag: request was already retried after a refresh.
  static const String kRetried = 'retried';

  /// `extra` key: the `IdempotencyKey` value to send as the `Idempotency-Key`
  /// header (payment, payout, draw and reminder writes).
  static const String kIdempotencyKey = 'idempotencyKey';
}
