import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'unlock_with_biometric_usecase.g.dart';

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

@Riverpod(keepAlive: true)
UnlockWithBiometricUseCase unlockWithBiometricUseCase(Ref ref) => UnlockWithBiometricUseCase(
  ref.watch(authRepositoryProvider),
  ref.watch(biometricServiceProvider),
);
