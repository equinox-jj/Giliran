import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'get_biometric_enabled.g.dart';

class GetBiometricEnabled(final AuthRepository _repository) implements UseCase<bool, NoParams> {
  @override
  Future<Either<Failure, bool>> call(NoParams params) => _repository.readBiometricEnabled();
}

@riverpod
GetBiometricEnabled getBiometricEnabled(Ref ref) => GetBiometricEnabled(ref.watch(authRepositoryProvider));
