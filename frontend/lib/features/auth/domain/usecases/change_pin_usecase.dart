import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'change_pin_usecase.g.dart';

typedef ChangePinParams = ({
  String currentPin,
  String newPin,
  String newPinConfirmation,
});

class ChangePinUseCase(final AuthRepository _repository) implements UseCase<Unit, ChangePinParams> {
  @override
  Future<Either<Failure, Unit>> call(ChangePinParams params) => _repository.changePin(
    currentPin: params.currentPin,
    newPin: params.newPin,
    newPinConfirmation: params.newPinConfirmation,
  );
}

@riverpod
ChangePinUseCase changePinUseCase(Ref ref) => ChangePinUseCase(ref.watch(authRepositoryProvider));
