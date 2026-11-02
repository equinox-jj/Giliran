import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'verify_pin.g.dart';

/// Checks a PIN with the server, for app unlock and sensitive actions.
class VerifyPin(final AuthRepository _repository) implements UseCase<Unit, String> {
  @override
  Future<Either<Failure, Unit>> call(String pin) => _repository.verifyPin(pin);
}

@riverpod
VerifyPin verifyPin(Ref ref) => VerifyPin(ref.watch(authRepositoryProvider));
