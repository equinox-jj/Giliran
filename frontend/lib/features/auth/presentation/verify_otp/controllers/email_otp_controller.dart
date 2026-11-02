import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../domain/entities/email_otp_challenge.dart';
import '../../../domain/entities/email_otp_result.dart';
import '../../../domain/usecases/get_pending_otp_usecase.dart';
import '../../../domain/usecases/resend_email_otp_usecase.dart';
import '../../../domain/usecases/verify_email_otp_usecase.dart';
import '../../shared/controllers/auth_session_controller.dart';

part 'email_otp_controller.freezed.dart';
part 'email_otp_controller.g.dart';

/// What the email code card (8.35) shows on S04 and S09 step 2.
///
/// [pending] is null when there is no open code request, and the page goes
/// back to S03. [pinRequired] turns on the PIN step after `pin_required`.
/// [result] is set once the code is verified.
@freezed
abstract class EmailOtpState with _$EmailOtpState {
  const factory({
    PendingOtp? pending,
    @Default(false) bool pinRequired,
    @Default(false) bool submitting,
    @Default(false) bool resending,
    Failure? failure,
    EmailOtpResult? result,
  }) = _EmailOtpState;
}

/// Verifies and resends the open email code. A verify that starts a session
/// moves [AuthSessionController] on, which lets the guard pick the next
/// screen.
@riverpod
class EmailOtpController() extends _$EmailOtpController {
  @override
  Future<EmailOtpState> build() async {
    final pending = await ref.read(getPendingOtpUseCaseProvider)(const NoParams());
    return pending.fold(
      (failure) => throw failure,
      (pending) => EmailOtpState(pending: pending),
    );
  }

  /// Verifies [code], with [pin] on the PIN step of an existing account, or
  /// with [newPin] and [newPinConfirmation] for `reset_pin` (S09).
  Future<void> verify(
    String code, {
    String? pin,
    String? newPin,
    String? newPinConfirmation,
  }) async {
    final current = state.value;
    final challenge = current?.pending?.challenge;
    final otpId = challenge?.id;
    final purpose = challenge?.purpose;
    if (current == null || current.submitting || otpId == null || purpose == null) {
      return;
    }

    state = AsyncData(current.copyWith(submitting: true, failure: null));

    final result = await ref.read(verifyEmailOtpUseCaseProvider)((
      otpId: otpId,
      purpose: purpose,
      code: code,
      pin: pin,
      newPin: newPin,
      newPinConfirmation: newPinConfirmation,
    ));
    if (!ref.mounted) return;

    switch (result) {
      case Left(value: final failure):
        state = AsyncData(
          current.copyWith(
            submitting: false,
            failure: failure,
            pinRequired: current.pinRequired || failure.apiCode == ApiErrorCode.pinRequired,
            pending: _withAttempts(current.pending, failure),
          ),
        );
      case Right(value: final verified):
        state = AsyncData(
          current.copyWith(submitting: false, failure: null, result: verified),
        );
        if (verified.auth != null) {
          await ref.read(authSessionControllerProvider.notifier).refresh(unlocked: pin != null || newPin != null);
        }
    }
  }

  /// Sends a new code for the same request and restarts the countdown.
  Future<void> resend() async {
    final current = state.value;
    final challenge = current?.pending?.challenge;
    final otpId = challenge?.id;
    final purpose = challenge?.purpose;
    if (current == null || current.resending || otpId == null || purpose == null) {
      return;
    }

    // Keep the failure while sending, so an expired card shows the spinner
    // on "Kirim kode baru" instead of flipping back to empty boxes early.
    state = AsyncData(current.copyWith(resending: true));

    final result = await ref.read(resendEmailOtpUseCaseProvider)((
      otpId: otpId,
      purpose: purpose,
    ));
    if (!ref.mounted) return;

    state = AsyncData(
      switch (result) {
        Left(value: final failure) => current.copyWith(
          resending: false,
          failure: failure,
        ),
        // A new code reopens the card: drop the old failure (such as
        // otp_expired) so the code boxes come back.
        Right(value: final sent) => current.copyWith(
          resending: false,
          failure: null,
          pending: current.pending?.copyWith(challenge: sent),
        ),
      },
    );
  }

  /// Carries the server's attempts left onto the challenge after a wrong
  /// code, so the card shows the new count.
  PendingOtp? _withAttempts(PendingOtp? pending, Failure failure) {
    final attempts = failure.attemptsRemaining;
    final challenge = pending?.challenge;
    if (failure.apiCode != ApiErrorCode.otpInvalid || attempts == null || challenge == null) {
      return pending;
    }

    return pending?.copyWith(
      challenge: challenge.copyWith(attemptsRemaining: attempts),
    );
  }
}
