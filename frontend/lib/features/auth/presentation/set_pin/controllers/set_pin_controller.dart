import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/usecases/set_pin_usecase.dart';
import '../../shared/controllers/auth_session_controller.dart';

part 'set_pin_controller.freezed.dart';
part 'set_pin_controller.g.dart';

/// The two-step PIN pad on S06. [firstPin] is null on "Buat PIN 6 digit"
/// and set on "Ulangi PIN".
@freezed
abstract class SetPinState with _$SetPinState {
  const factory({
    String? firstPin,
    @Default(false) bool submitting,
    @Default(false) bool done,
    Failure? failure,
  }) = _SetPinState;
}

/// Collects the new PIN twice and sets it. The API checks the match and
/// strength (`pin_too_weak`); any failure starts the pad over.
@riverpod
class SetPinController() extends _$SetPinController {
  @override
  SetPinState build() => const SetPinState();

  /// Takes a full 6-digit entry: the first one is kept, the second submits.
  Future<void> enter(String pin) async {
    final current = state;
    if (current.submitting || current.done) return;

    final firstPin = current.firstPin;
    if (firstPin == null) {
      state = SetPinState(firstPin: pin);
      return;
    }

    state = current.copyWith(submitting: true, failure: null);
    final result = await ref.read(setPinUseCaseProvider)((
      pin: firstPin,
      pinConfirmation: pin,
    ));
    if (!ref.mounted) return;

    switch (result) {
      case Left(value: final failure):
        state = SetPinState(failure: failure);
      case Right():
        state = const SetPinState(done: true);
        await ref.read(authSessionControllerProvider.notifier).refresh(unlocked: true);
    }
  }

  /// Back to the first entry, such as from the app bar's back on step 2.
  void restart() => state = const SetPinState();
}
