import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'set_pin.g.dart';

typedef SetPinParams = ({String pin, String pinConfirmation});

class SetPin(final AuthRepository _repository) implements UseCase<Unit, SetPinParams> {
  @override
  Future<Either<Failure, Unit>> call(SetPinParams params) => _repository.setPin(
    pin: params.pin,
    pinConfirmation: params.pinConfirmation,
  );
}

@riverpod
SetPin setPin(Ref ref) => SetPin(ref.watch(authRepositoryProvider));
