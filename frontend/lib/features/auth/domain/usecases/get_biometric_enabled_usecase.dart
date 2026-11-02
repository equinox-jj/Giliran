import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'get_biometric_enabled_usecase.g.dart';

class GetBiometricEnabledUseCase(final AuthRepository _repository) implements UseCase<bool, NoParams> {
  @override
  Future<Either<Failure, bool>> call(NoParams params) => _repository.readBiometricEnabled();
}

@riverpod
GetBiometricEnabledUseCase getBiometricEnabledUseCase(Ref ref) =>
    GetBiometricEnabledUseCase(ref.watch(authRepositoryProvider));
