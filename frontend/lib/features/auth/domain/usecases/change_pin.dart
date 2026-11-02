import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'change_pin.g.dart';

typedef ChangePinParams = ({
  String currentPin,
  String newPin,
  String newPinConfirmation,
});

class ChangePin(final AuthRepository _repository) implements UseCase<Unit, ChangePinParams> {
  @override
  Future<Either<Failure, Unit>> call(ChangePinParams params) => _repository.changePin(
    currentPin: params.currentPin,
    newPin: params.newPin,
    newPinConfirmation: params.newPinConfirmation,
  );
}

@riverpod
ChangePin changePin(Ref ref) => ChangePin(ref.watch(authRepositoryProvider));
