import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../domain/usecases/unlock_with_biometric_usecase.dart';
import '../../../domain/usecases/verify_pin_usecase.dart';
import '../../shared/controllers/auth_session_controller.dart';

part 'pin_lock_controller.freezed.dart';
part 'pin_lock_controller.g.dart';

@freezed
abstract class PinLockState with _$PinLockState {
  const factory({
    @Default(false) bool submitting,
    int? attemptsRemaining,
    DateTime? lockedUntil,
    Failure? failure,
  }) = _PinLockState;
}

/// Unlocks the session with the PIN or biometric, or signs out.
@riverpod
class PinLockController() extends _$PinLockController {
  @override
  PinLockState build() => const PinLockState();

  Future<void> verify(String pin) async {
    final current = state;
    if (current.submitting) return;

    state = current.copyWith(submitting: true, failure: null);

    final result = await ref.read(verifyPinUseCaseProvider)(pin);
    if (!ref.mounted) return;

    switch (result) {
      case Left(value: final failure):
        final retryAfter = failure.retryAfterDelay;
        state = current.copyWith(
          submitting: false,
          failure: failure,
          attemptsRemaining: failure.attemptsRemaining ?? current.attemptsRemaining,
          lockedUntil: failure.apiCode == ApiErrorCode.pinLocked && retryAfter != null
              ? DateTime.now().add(retryAfter)
              : current.lockedUntil,
        );
      case Right():
        state = const PinLockState();
        ref.read(authSessionControllerProvider.notifier).unlock();
    }
  }

  /// Drops the shown error once the user starts a new entry.
  void clearFailure() {
    if (state.failure != null) state = state.copyWith(failure: null);
  }

  /// Shows the biometric prompt with [reason]; a pass unlocks. A cancel or
  /// an unavailable biometric leaves the PIN pad as it is.
  Future<void> unlockWithBiometric(String reason) async {
    if (state.submitting) return;

    final result = await ref.read(unlockWithBiometricUseCaseProvider)(reason);
    if (!ref.mounted) return;
    if (result case Right(value: true)) {
      ref.read(authSessionControllerProvider.notifier).unlock();
    }
  }

  /// "Bukan kamu? Keluar", after the confirm dialog.
  Future<Failure?> logout() => ref.read(authSessionControllerProvider.notifier).logout();
}
