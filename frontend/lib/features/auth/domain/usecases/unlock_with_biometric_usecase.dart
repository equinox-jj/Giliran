import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'unlock_with_biometric_usecase.g.dart';

/// Shows the system biometric prompt with the given reason, for the S08 key
/// and its auto-prompt. True only when biometric unlock is on, a biometric
/// is enrolled and the user passed; otherwise the PIN stays the way in.
class UnlockWithBiometricUseCase(
  final AuthRepository _repository,
  final BiometricService _biometric,
) implements UseCase<bool, String> {
  @override
  Future<Either<Failure, bool>> call(String reason) async {
    final enabled = await _repository.readBiometricEnabled();
    if (enabled case Right(value: true)) {
      if (await _biometric.availableKind() == null) return const Right(false);
      return Right(await _biometric.authenticate(reason));
    }
    return enabled.map((_) => false);
  }
}

@riverpod
UnlockWithBiometricUseCase unlockWithBiometricUseCase(Ref ref) => UnlockWithBiometricUseCase(
  ref.watch(authRepositoryProvider),
  ref.watch(biometricServiceProvider),
);
