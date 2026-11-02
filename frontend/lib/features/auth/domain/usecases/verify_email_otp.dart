import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import '../entities/email_otp_result.dart';

part 'verify_email_otp.g.dart';

typedef VerifyEmailOtpParams = ({
  String otpId,
  OtpPurpose purpose,
  String code,
  String? pin,
  String? newPin,
  String? newPinConfirmation,
});

/// Verifies an email code and drops the pending code once it is used.
/// Fails with `pin_required` when the account must also send a PIN.
class VerifyEmailOtp(final AuthRepository _repository) implements UseCase<EmailOtpResult, VerifyEmailOtpParams> {
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
    if (result.isRight()) {
      // The code is consumed on the server; a stale local copy is harmless.
      await _repository.clearPendingOtp();
    }
    return result;
  }
}

@riverpod
VerifyEmailOtp verifyEmailOtp(Ref ref) => VerifyEmailOtp(ref.watch(authRepositoryProvider));
