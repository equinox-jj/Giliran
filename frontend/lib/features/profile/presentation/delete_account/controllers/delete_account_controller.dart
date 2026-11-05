import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../auth/presentation/shared/controllers/auth_session_controller.dart';
import '../../../domain/usecases/delete_account_usecase.dart';

part 'delete_account_controller.freezed.dart';
part 'delete_account_controller.g.dart';

enum DeleteAccountStep() {
  /// What is deleted and what stays, with "Saya mengerti".
  explain,
  pin,
  done,
}

@freezed
abstract class DeleteAccountState with _$DeleteAccountState {
  const factory({
    @Default(DeleteAccountStep.explain) DeleteAccountStep step,
    @Default(false) bool understood,
    @Default(false) bool submitting,

    /// The server refused with `obligations_outstanding`; continue stays off.
    @Default(false) bool blocked,
    Failure? failure,

    /// Set after `pin_locked`, from `Retry-After`, for the lock countdown.
    DateTime? lockedUntil,
  }) = _DeleteAccountState;
}

/// The three-step Delete account flow.
@riverpod
class DeleteAccountController() extends _$DeleteAccountController {
  @override
  DeleteAccountState build() => const DeleteAccountState();

  void setUnderstood(bool value) => state = state.copyWith(understood: value);

  /// Step 1 → PIN, once the user checked "Saya mengerti" and nothing blocks.
  void next() {
    if (state.step == DeleteAccountStep.explain && state.understood && !state.blocked) {
      state = state.copyWith(step: DeleteAccountStep.pin, failure: null);
    }
  }

  /// One step back. Returns false on the first step, where the page closes.
  bool back() {
    if (state.submitting) return true;
    switch (state.step) {
      case DeleteAccountStep.pin:
        state = state.copyWith(step: DeleteAccountStep.explain, failure: null, lockedUntil: null);
        return true;
      case DeleteAccountStep.explain || DeleteAccountStep.done:
        return false;
    }
  }

  void clearFailure() {
    if (state.failure != null && state.lockedUntil == null && state.step == DeleteAccountStep.pin) {
      state = state.copyWith(failure: null);
    }
  }

  void lockFinished() => state = state.copyWith(lockedUntil: null, failure: null);

  /// Sends the PIN from step 2.
  Future<void> enter(String pin) async {
    if (state.submitting || state.step != DeleteAccountStep.pin || state.lockedUntil != null) return;
    state = state.copyWith(submitting: true, failure: null);

    final result = await ref.read(deleteAccountUseCaseProvider)(pin);
    if (!ref.mounted) return;

    state = switch (result) {
      Right() => state.copyWith(step: DeleteAccountStep.done, submitting: false),
      Left(value: final failure) => switch (failure.apiCode) {
        ApiErrorCode.obligationsOutstanding => state.copyWith(
          step: DeleteAccountStep.explain,
          submitting: false,
          blocked: true,
          failure: failure,
        ),
        ApiErrorCode.pinLocked => state.copyWith(
          submitting: false,
          failure: failure,
          lockedUntil: switch (failure.retryAfterDelay) {
            final delay? => DateTime.now().add(delay),
            null => null,
          },
        ),
        _ => state.copyWith(submitting: false, failure: failure),
      },
    };
  }

  /// "Selesai" on the done step: re-reads the now-empty session, so the
  /// router guard lands on Welcome.
  Future<void> finish() => ref.read(authSessionControllerProvider.notifier).refresh();
}
