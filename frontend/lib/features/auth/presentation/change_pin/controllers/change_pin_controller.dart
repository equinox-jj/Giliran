import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../domain/usecases/change_pin_usecase.dart';

part 'change_pin_controller.freezed.dart';
part 'change_pin_controller.g.dart';

/// The pad step on S45: current PIN, new PIN, then the new PIN again.
enum ChangePinStep() {
  current,
  newPin,
  confirm,
}

@freezed
abstract class ChangePinState with _$ChangePinState {
  const factory({
    @Default(ChangePinStep.current) ChangePinStep step,
    String? currentPin,
    String? newPin,
    @Default(false) bool submitting,
    @Default(false) bool done,
    Failure? failure,
  }) = _ChangePinState;
}

/// Steps through S45 and changes the PIN. A wrong or locked current PIN
/// goes back to the first step; any other failure (such as `pin_too_weak`
/// or a mismatch) goes back to the new PIN.
@riverpod
class ChangePinController() extends _$ChangePinController {
  @override
  ChangePinState build() => const ChangePinState();

  /// Takes a full 6-digit entry for the current step.
  Future<void> enter(String pin) async {
    final current = state;
    if (current.submitting || current.done) return;

    switch (current.step) {
      case ChangePinStep.current:
        state = ChangePinState(step: ChangePinStep.newPin, currentPin: pin);
      case ChangePinStep.newPin:
        state = current.copyWith(
          step: ChangePinStep.confirm,
          newPin: pin,
          failure: null,
        );
      case ChangePinStep.confirm:
        await _submit(current, pin);
    }
  }

  Future<void> _submit(ChangePinState current, String confirmation) async {
    final currentPin = current.currentPin;
    final newPin = current.newPin;
    if (currentPin == null || newPin == null) return;

    state = current.copyWith(submitting: true, failure: null);

    final result = await ref.read(changePinUseCaseProvider)((
      currentPin: currentPin,
      newPin: newPin,
      newPinConfirmation: confirmation,
    ));
    if (!ref.mounted) return;

    state = switch (result) {
      Left(value: final failure) => switch (failure.apiCode) {
        ApiErrorCode.pinInvalid || ApiErrorCode.pinLocked => ChangePinState(failure: failure),
        _ => ChangePinState(
          step: ChangePinStep.newPin,
          currentPin: currentPin,
          failure: failure,
        ),
      },
      Right() => const ChangePinState(done: true),
    };
  }
}
