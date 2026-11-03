import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/biometric_status.dart';
import '../repositories/auth_repository.dart';

part 'get_biometric_status_usecase.g.dart';

class GetBiometricStatusUseCase(
  final AuthRepository _repository,
  final BiometricService _biometric,
) implements UseCase<BiometricStatus, NoParams> {
  @override
  Future<Either<Failure, BiometricStatus>> call(NoParams params) async {
    final kind = await _biometric.availableKind();
    final enabled = await _repository.readBiometricEnabled();
    if (enabled case Left(:final value)) return Left(value);
    final isEnabled = enabled.getOrElse((_) => false);
    final prompted = await _repository.readBiometricPrompted();
    return prompted.map(
      (prompted) => BiometricStatus(
        kind: kind,
        enabled: isEnabled,
        shouldOffer: kind != null && !isEnabled && !prompted,
      ),
    );
  }
}

@riverpod
GetBiometricStatusUseCase getBiometricStatusUseCase(Ref ref) => GetBiometricStatusUseCase(
  ref.watch(authRepositoryProvider),
  ref.watch(biometricServiceProvider),
);
