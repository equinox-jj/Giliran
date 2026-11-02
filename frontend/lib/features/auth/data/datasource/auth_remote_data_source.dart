import '../../../../core/utils/enums/otp_purpose.dart';
import 'model/email_otp_challenge_model.dart';
import 'model/email_otp_request_model.dart';
import 'model/email_otp_result_model.dart';
import 'model/email_otp_verify_request_model.dart';
import 'model/pin_request_models.dart';

/// The `/auth/*` endpoints: email codes, PIN and logout. Token refresh is
/// handled by `RefreshInterceptor`, not here.
///
/// Every method throws a typed `AppException` on failure.
abstract interface class AuthRemoteDataSource {
  /// `POST /auth/email/otp`: sends a 6-digit code to `body.email`.
  Future<EmailOtpChallengeModel> requestEmailOtp(EmailOtpRequestModel body);

  /// `POST /auth/email/otp/{otpId}/resend`: replaces the code, available 60 s
  /// after the last send.
  Future<EmailOtpChallengeModel> resendEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
  });

  /// `POST /auth/email/otp/{otpId}/verify`. Throws `pin_required` (422) when
  /// the code is right but the account must also send its PIN.
  Future<EmailOtpResultModel> verifyEmailOtp(
    String otpId,
    EmailOtpVerifyRequestModel body, {
    required OtpPurpose purpose,
  });

  /// `POST /auth/pin`: sets the first PIN.
  Future<void> setPin(SetPinRequestModel body);

  /// `PUT /auth/pin`: changes the PIN with the current one.
  Future<void> changePin(ChangePinRequestModel body);

  /// `POST /auth/pin/verify`: unlocks the app.
  Future<void> verifyPin(PinRequestModel body);

  /// `POST /auth/logout`: revokes the current session.
  Future<void> logout();
}
