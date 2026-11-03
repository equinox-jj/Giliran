import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import '../entities/email_otp_result.dart';

part 'verify_email_otp_usecase.g.dart';

typedef VerifyEmailOtpParams = ({
  String otpId,
  OtpPurpose purpose,
  String code,
  String? pin,
  String? newPin,
  String? newPinConfirmation,
});

/// Verifies an email code, drops the pending code once it is used and caches
/// the updated user after a `change_email`.
/// Fails with `pin_required` when the account must also send a PIN.
class VerifyEmailOtpUseCase(final AuthRepository _repository) implements UseCase<EmailOtpResult, VerifyEmailOtpParams> {
  @override
  Future<Either<Failure, EmailOtpResult>> call(
    VerifyEmailOtpParams params,
  ) async {
    final result = await _repository.verifyEmailOtp(
      params.otpId,
      purpose: params.purpose,
      code: params.code,
      pin: params.pin,
      newPin: params.newPin,
      newPinConfirmation: params.newPinConfirmation,
    );
    if (result case Right(value: final verified)) {
      // The code is consumed on the server; a stale local copy is harmless.
      await _repository.clearPendingOtp();
      // A changed email comes back as the updated user (sign-in results are
      // cached by the repository with their tokens).
      if (verified.user case final user?) {
        await _repository.saveCurrentUser(user);
      }
    }
    return result;
  }
}

@Riverpod(keepAlive: true)
VerifyEmailOtpUseCase verifyEmailOtpUseCase(Ref ref) => VerifyEmailOtpUseCase(ref.watch(authRepositoryProvider));
