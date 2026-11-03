import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';
import '../entities/email_otp_challenge.dart';

part 'get_pending_otp_usecase.g.dart';

/// Returns the unfinished code request to resume, or null. An expired one is
/// removed and treated as none.
class GetPendingOtpUseCase(
  final AuthRepository _repository, {
  final DateTime Function() _now = DateTime.now,
}) implements UseCase<PendingOtp?, NoParams> {
  @override
  Future<Either<Failure, PendingOtp?>> call(NoParams params) async {
    final result = await _repository.readPendingOtp();
    if (result case Right(value: final pending?)) {
      final expiresAt = pending.challenge?.expiresAt;
      if (expiresAt != null && !expiresAt.isAfter(_now())) {
        await _repository.clearPendingOtp();
        return const Right(null);
      }
    }
    return result;
  }
}

@Riverpod(keepAlive: true)
GetPendingOtpUseCase getPendingOtpUseCase(Ref ref) => GetPendingOtpUseCase(ref.watch(authRepositoryProvider));
