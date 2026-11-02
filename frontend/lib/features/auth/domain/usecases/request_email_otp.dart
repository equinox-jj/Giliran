import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/utils/enums/otp_purpose.dart';
import '../entities/email_otp_challenge.dart';

part 'request_email_otp.g.dart';

typedef RequestEmailOtpParams = ({
  OtpPurpose purpose,
  String email,
  String? pin,
});

/// Sends an email code and keeps it as the pending code, so the code screen
/// can resume after the app is closed.
class RequestEmailOtp(final AuthRepository _repository) implements UseCase<EmailOtpChallenge, RequestEmailOtpParams> {
  @override
  Future<Either<Failure, EmailOtpChallenge>> call(
    RequestEmailOtpParams params,
  ) async {
    final result = await _repository.requestEmailOtp(
      purpose: params.purpose,
      email: params.email,
      pin: params.pin,
    );
    if (result case Right(value: final challenge)) {
      // The code is already sent, so a failed save must not fail the request.
      await _repository.savePendingOtp(
        PendingOtp(email: params.email, challenge: challenge),
      );
    }
    return result;
  }
}

@riverpod
RequestEmailOtp requestEmailOtp(Ref ref) => RequestEmailOtp(ref.watch(authRepositoryProvider));
