import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'set_biometric_enabled.g.dart';

/// Turns biometric unlock on or off and marks the opt-in as offered, so it
/// is not asked again.
class SetBiometricEnabled(final AuthRepository _repository) implements UseCase<Unit, bool> {
  @override
  Future<Either<Failure, Unit>> call(bool enabled) async {
    final saved = await _repository.saveBiometricEnabled(enabled);
    if (saved.isLeft()) return saved;
    return _repository.saveBiometricPrompted(true);
  }
}

@riverpod
SetBiometricEnabled setBiometricEnabled(Ref ref) => SetBiometricEnabled(ref.watch(authRepositoryProvider));
