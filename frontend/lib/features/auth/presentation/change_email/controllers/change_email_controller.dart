import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/enums/otp_purpose.dart';
import '../../../domain/usecases/request_email_otp_usecase.dart';
import '../../../domain/usecases/validate_new_email_usecase.dart';
import '../../verify_otp/controllers/email_otp_controller.dart';

part 'change_email_controller.freezed.dart';
part 'change_email_controller.g.dart';

enum ChangeEmailStep() {
  /// The current address and a field for the new one.
  email,

  /// The current PIN, sent with the code request.
  pin,

  /// The email code card for the code sent to the new address.
  code,
}

@freezed
abstract class ChangeEmailState with _$ChangeEmailState {
  const factory({
    @Default(ChangeEmailStep.email) ChangeEmailStep step,

    /// The new address, normalized, once step 1 passed.
    String? newEmail,
    @Default(false) bool submitting,

    /// Shown on the step it belongs to: email errors on step 1, PIN errors
    /// on step 2.
    Failure? failure,

    /// Set after `pin_locked`, from `Retry-After`, for the lock countdown.
    DateTime? lockedUntil,
  }) = _ChangeEmailState;
}

@riverpod
class ChangeEmailController() extends _$ChangeEmailController {
  @override
  ChangeEmailState build() => const ChangeEmailState();

  /// Step 1: checks the new address and moves on to the PIN.
  Future<void> submitEmail(String email) async {
    final current = state;
    if (current.submitting) return;

    state = current.copyWith(submitting: true, failure: null);
    final result = await ref.read(validateNewEmailUseCaseProvider)(email);
    if (!ref.mounted) return;

    state = switch (result) {
      Left(value: final failure) => current.copyWith(submitting: false, failure: failure),
      Right(value: final normalized) => ChangeEmailState(step: ChangeEmailStep.pin, newEmail: normalized),
    };
  }

  /// Step 2: sends the code to the new address with the current [pin].
  /// A taken or invalid address goes back to step 1 with the error.
  Future<void> submitPin(String pin) async {
    final current = state;
    final email = current.newEmail;
    if (current.submitting || current.lockedUntil != null || email == null) return;

    state = current.copyWith(submitting: true, failure: null);
    final result = await ref.read(requestEmailOtpUseCaseProvider)((
      purpose: OtpPurpose.changeEmail,
      email: email,
      pin: pin,
    ));
    if (!ref.mounted) return;

    switch (result) {
      case Right():
        // The code card reads the request just saved.
        ref.invalidate(emailOtpControllerProvider);
        state = current.copyWith(step: ChangeEmailStep.code, submitting: false);
      case Left(value: final failure):
        state = switch (failure) {
          _ when failure.apiCode == ApiErrorCode.pinLocked => current.copyWith(
            submitting: false,
            failure: failure,
            lockedUntil: switch (failure.retryAfterDelay) {
              final delay? => DateTime.now().add(delay),
              null => null,
            },
          ),
          ValidationFailure() || ConflictFailure() => ChangeEmailState(newEmail: email, failure: failure),
          _ => current.copyWith(submitting: false, failure: failure),
        };
    }
  }

  /// Goes back one step. Returns false on step 1, where the page closes.
  bool back() {
    final current = state;
    if (current.submitting) return true;
    switch (current.step) {
      case ChangeEmailStep.email:
        return false;
      case ChangeEmailStep.pin:
        state = ChangeEmailState(newEmail: current.newEmail);
      case ChangeEmailStep.code:
        state = ChangeEmailState(step: ChangeEmailStep.pin, newEmail: current.newEmail);
    }
    return true;
  }

  /// Back to step 1 with the new address kept ("Ubah" on the code card).
  void editEmail() => state = ChangeEmailState(newEmail: state.newEmail);

  /// Drops the shown error once the user edits or types again.
  void clearFailure() {
    if (state.failure != null && state.lockedUntil == null) {
      state = state.copyWith(failure: null);
    }
  }

  /// The lock countdown ran out: the PIN can be tried again.
  void lockFinished() => state = state.copyWith(failure: null, lockedUntil: null);
}
