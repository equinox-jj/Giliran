import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../domain/usecases/change_pin_usecase.dart';

part 'change_pin_controller.freezed.dart';
part 'change_pin_controller.g.dart';

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

    /// Set after `pin_locked`, from `Retry-After`, for the lock countdown.
    DateTime? lockedUntil,
  }) = _ChangePinState;
}

@riverpod
class ChangePinController() extends _$ChangePinController {
  @override
  ChangePinState build() => const ChangePinState();

  /// Takes a full 6-digit entry for the current step.
  Future<void> enter(String pin) async {
    final current = state;
    if (current.submitting || current.done || current.lockedUntil != null) return;

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

  /// The back button: one step back, keeping the PINs before it. Returns
  /// false on the first step, where the page closes.
  bool back() {
    final current = state;
    if (current.submitting) return true;
    switch (current.step) {
      case ChangePinStep.current:
        return false;
      case ChangePinStep.newPin:
        state = const ChangePinState();
      case ChangePinStep.confirm:
        state = ChangePinState(step: ChangePinStep.newPin, currentPin: current.currentPin);
    }
    return true;
  }

  /// Drops the shown error once the user starts a new entry.
  void clearFailure() {
    if (state.failure != null && state.lockedUntil == null) {
      state = state.copyWith(failure: null);
    }
  }

  /// The lock countdown ran out: the current PIN can be tried again.
  void lockFinished() => state = const ChangePinState();

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
        ApiErrorCode.pinInvalid => ChangePinState(failure: failure),
        ApiErrorCode.pinLocked => ChangePinState(
          failure: failure,
          lockedUntil: switch (failure.retryAfterDelay) {
            final delay? => DateTime.now().add(delay),
            null => null,
          },
        ),
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
