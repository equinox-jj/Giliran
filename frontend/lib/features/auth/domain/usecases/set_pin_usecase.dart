import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

part 'set_pin_usecase.g.dart';

typedef SetPinParams = ({String pin, String pinConfirmation});

/// Sets the account's first PIN (S06) and marks the cached user as having
/// one, so the launch gate does not ask for a PIN again.
class SetPinUseCase(final AuthRepository _repository) implements UseCase<Unit, SetPinParams> {
  @override
  Future<Either<Failure, Unit>> call(SetPinParams params) async {
    final result = await _repository.setPin(
      pin: params.pin,
      pinConfirmation: params.pinConfirmation,
    );
    if (result.isRight()) {
      final user = (await _repository.readCurrentUser()).toNullable();
      if (user != null) {
        // The PIN is set on the server; a failed cache write only means the
        // next launch asks to set it again, where the API answers
        // `pin_already_set`.
        await _repository.saveCurrentUser(user.copyWith(pinSet: true));
      }
    }
    return result;
  }
}

@riverpod
SetPinUseCase setPinUseCase(Ref ref) => SetPinUseCase(ref.watch(authRepositoryProvider));
