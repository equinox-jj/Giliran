/// Central registry of the API base URL, paths, and `RequestOptions.extra`
/// keys.
abstract final class ApiEndpoints() {
  /// Base URL for all requests. Override with
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1` android
  /// `--dart-define=API_BASE_URL=http://localhost:8080/api/v1` ios
  /// for a local backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  /// The public site behind invite, claim and verification links.
  static const String webBaseUrl = 'https://giliran.monai.my.id';

  /// Public draw verification page (`/v/{code}`), opened in the browser.
  static Uri verifyPage(String code) => Uri.parse('$webBaseUrl/v/$code');

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

  /// Sets the winning order of a fixed-order group (`PUT`).
  static String fixedOrder(String groupId) => '/groups/$groupId/fixed-order';

  /// Starts a draft group and opens period 1 (`POST`).
  static String groupStart(String groupId) => '/groups/$groupId/start';

  /// Replaces the invite code; old links stop working (`POST`).
  static String inviteReset(String groupId) => '/groups/$groupId/invite-code/reset';

  /// Group preview from an invite code (`GET`).
  static String invite(String code) => '/invites/$code';

  /// Joins the group behind an invite code (`POST`).
  static String inviteJoin(String code) => '/invites/$code/join';

  /// Members and guests (`GET`, `?status=active|all`).
  static String members(String groupId) => '/groups/$groupId/members';

  /// Adds a guest to the next free slot (`POST`).
  static String guests(String groupId) => '/groups/$groupId/guests';

  /// One member (`GET`), guest edit (`PATCH`), removal (`DELETE`).
  static String member(String groupId, String memberId) => '/groups/$groupId/members/$memberId';

  /// A link a guest uses to take over their slot (`POST`).
  static String claimLink(String groupId, String memberId) => '/groups/$groupId/members/$memberId/claim-link';

  /// Claims a guest slot with the signed-in account (`POST`).
  static String claim(String token) => '/claims/$token';

  /// Leave requests (`GET`, `?status=`) and asking to leave (`POST`).
  static String leaveRequests(String groupId) => '/groups/$groupId/leave-requests';

  /// Approves a leave request (`POST`).
  static String leaveApprove(String groupId, String requestId) => '/groups/$groupId/leave-requests/$requestId/approve';

  /// Rejects a leave request (`POST`).
  static String leaveReject(String groupId, String requestId) => '/groups/$groupId/leave-requests/$requestId/reject';

  /// Offers the organizer role to another member (`POST`).
  static String ownershipTransfers(String groupId) => '/groups/$groupId/ownership-transfers';

  /// Accepts the organizer role (`POST`).
  static String transferAccept(String groupId, String transferId) =>
      '/groups/$groupId/ownership-transfers/$transferId/accept';

  /// Declines the organizer role (`POST`).
  static String transferDecline(String groupId, String transferId) =>
      '/groups/$groupId/ownership-transfers/$transferId/decline';

  /// Remaining obligations of past winners (`GET`).
  static String obligations(String groupId) => '/groups/$groupId/obligations';

  /// A group's periods in order (`GET`).
  static String periods(String groupId) => '/groups/$groupId/periods';

  /// One period (`GET`).
  static String period(String groupId, String periodId) => '/groups/$groupId/periods/$periodId';

  /// A period's payment board with `meta.summary` (`GET`).
  static String periodPayments(String groupId, String periodId) => '/groups/$groupId/periods/$periodId/payments';

  /// One payment with every proof (`GET`).
  static String payment(String groupId, String paymentId) => '/groups/$groupId/payments/$paymentId';

  /// Uploads a transfer screenshot (`POST` multipart).
  static String paymentProofs(String groupId, String paymentId) => '/groups/$groupId/payments/$paymentId/proofs';

  /// Approves a pending proof (`POST`).
  static String paymentApprove(String groupId, String paymentId) => '/groups/$groupId/payments/$paymentId/approve';

  /// Rejects a pending proof with a reason (`POST`).
  static String paymentReject(String groupId, String paymentId) => '/groups/$groupId/payments/$paymentId/reject';

  /// Marks a payment paid without a proof (`POST`).
  static String paymentMarkPaid(String groupId, String paymentId) => '/groups/$groupId/payments/$paymentId/mark-paid';

  /// A period's payout (`GET`) and recording it (`POST` multipart).
  static String payout(String groupId, String periodId) => '/groups/$groupId/periods/$periodId/payout';

  /// The winner confirms the pot arrived (`POST`).
  static String payoutConfirm(String groupId, String periodId) => '/groups/$groupId/periods/$periodId/payout/confirm';

  /// `extra` flag: skip attaching the access token (sign-in, refresh, public
  /// pages).
  static const String kNoAuth = 'noAuth';

  /// `extra` flag: request was already retried after a refresh.
  static const String kRetried = 'retried';

  /// `extra` key: the `IdempotencyKey` value to send as the `Idempotency-Key`
  /// header (payment, payout, draw and reminder writes).
  static const String kIdempotencyKey = 'idempotencyKey';
}
