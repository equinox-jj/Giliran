import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'should_offer_biometric_usecase.g.dart';

/// Whether to show the one-time biometric opt-in: only when it is off and
/// has never been offered.
class ShouldOfferBiometricUseCase(final AuthRepository _repository) implements UseCase<bool, NoParams> {
  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    final enabled = await _repository.readBiometricEnabled();
    if (enabled case Right(value: false)) {
      final prompted = await _repository.readBiometricPrompted();
      return prompted.map((prompted) => !prompted);
    }
    return enabled.map((_) => false);
  }
}

@riverpod
ShouldOfferBiometricUseCase shouldOfferBiometricUseCase(Ref ref) =>
    ShouldOfferBiometricUseCase(ref.watch(authRepositoryProvider));
