import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/email_otp_challenge.dart';
import '../repositories/auth_repository.dart';

part 'resend_email_otp_usecase.g.dart';

typedef ResendEmailOtpParams = ({String otpId, OtpPurpose purpose});

/// Resends a code and refreshes the stored pending code when it is the same
/// request, so a resumed code screen shows the new countdown.
class ResendEmailOtpUseCase(
  final AuthRepository _repository,
) implements UseCase<EmailOtpChallenge, ResendEmailOtpParams> {
  @override
  Future<Either<Failure, EmailOtpChallenge>> call(
    ResendEmailOtpParams params,
  ) async {
    final result = await _repository.resendEmailOtp(
      params.otpId,
      purpose: params.purpose,
    );
    if (result case Right(value: final challenge)) {
      final pending = (await _repository.readPendingOtp()).toNullable();
      if (pending != null && pending.challenge?.id == params.otpId) {
        await _repository.savePendingOtp(pending.copyWith(challenge: challenge));
      }
    }
    return result;
  }
}

@riverpod
ResendEmailOtpUseCase resendEmailOtpUseCase(Ref ref) => ResendEmailOtpUseCase(ref.watch(authRepositoryProvider));
