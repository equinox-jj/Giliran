import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import '../../../profile/domain/entity/profile.dart';
import '../entities/email_otp_challenge.dart';
import '../entities/email_otp_result.dart';

/// Sign-in, PIN and on-device session state. Auth usecases depend on this.
///
/// Methods map one-to-one to the data sources; rules that combine them (such
/// as clearing the pending code after a verify) belong in the usecases.
abstract interface class AuthRepository() {
  /// Sends a code to [email]. [pin] is required only for `change_email`.
  /// Device name and platform are added from this device.
  Future<Either<Failure, EmailOtpChallenge>> requestEmailOtp({
    required OtpPurpose purpose,
    required String email,
    String? pin,
  });

  Future<Either<Failure, EmailOtpChallenge>> resendEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
  });

  /// Verifies [code]. When the result starts a session (`sign_in`,
  /// `reset_pin`), its tokens and user are stored before returning. Fails
  /// with `pin_required` when the account must also send [pin].
  Future<Either<Failure, EmailOtpResult>> verifyEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
    required String code,
    String? pin,
    String? newPin,
    String? newPinConfirmation,
  });

  Future<Either<Failure, Unit>> setPin({
    required String pin,
    required String pinConfirmation,
  });

  Future<Either<Failure, Unit>> changePin({
    required String currentPin,
    required String newPin,
    required String newPinConfirmation,
  });

  Future<Either<Failure, Unit>> verifyPin(String pin);

  /// Revokes the session on the server only. Pair with [clearSession].
  Future<Either<Failure, Unit>> logout();

  /// Removes tokens, the cached user and any pending code from the device.
  Future<Either<Failure, Unit>> clearSession();

  /// Whether a refresh token is stored, meaning a session may still exist.
  Future<Either<Failure, bool>> hasSession();

  Future<Either<Failure, ProfileData?>> readCurrentUser();

  Future<Either<Failure, Unit>> saveCurrentUser(ProfileData user);

  Future<Either<Failure, PendingOtp?>> readPendingOtp();

  Future<Either<Failure, Unit>> savePendingOtp(PendingOtp pending);

  Future<Either<Failure, Unit>> clearPendingOtp();

  Future<Either<Failure, bool>> readBiometricEnabled();

  Future<Either<Failure, Unit>> saveBiometricEnabled(bool enabled);

  /// Whether the biometric opt-in has already been offered once.
  Future<Either<Failure, bool>> readBiometricPrompted();

  Future<Either<Failure, Unit>> saveBiometricPrompted(bool prompted);
}
