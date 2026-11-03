import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/auth_status.dart';
import '../repositories/auth_repository.dart';
import 'get_pending_otp_usecase.dart';

part 'resolve_auth_status_usecase.g.dart';

/// [unlocked] is true right after the user proved the PIN (verify with PIN,
/// set PIN, reset PIN), so the lock screen is skipped.
typedef ResolveAuthStatusParams = ({bool unlocked});

/// Reads the device's session and applies the launch-gate rules of design
/// system 10.2: no session resumes an open code request or signs out; a
/// session without a name or PIN finishes onboarding; anything else locks.
class ResolveAuthStatusUseCase(
  final AuthRepository _repository,
  final GetPendingOtpUseCase _getPendingOtp,
) implements UseCase<AuthStatus, ResolveAuthStatusParams> {
  @override
  Future<Either<Failure, AuthStatus>> call(
    ResolveAuthStatusParams params,
  ) async {
    final hasSession = await _repository.hasSession();
    switch (hasSession) {
      case Left(:final value):
        return Left(value);
      case Right(value: false):
        final pending = await _getPendingOtp(const NoParams());
        return pending.map(
          (pending) => pending == null ? const AuthStatus.signedOut() : AuthStatus.otpPending(pending: pending),
        );
      case Right(value: true):
        final user = await _repository.readCurrentUser();
        return user.map((user) {
          if (user?.name?.trim().isEmpty ?? true) {
            return AuthStatus.needsName(user: user);
          }
          if (user?.pinSet != true) return AuthStatus.needsPin(user: user);
          return params.unlocked ? AuthStatus.unlocked(user: user) : AuthStatus.locked(user: user);
        });
    }
  }
}

@Riverpod(keepAlive: true)
ResolveAuthStatusUseCase resolveAuthStatusUseCase(Ref ref) => ResolveAuthStatusUseCase(
  ref.watch(authRepositoryProvider),
  ref.watch(getPendingOtpUseCaseProvider),
);
