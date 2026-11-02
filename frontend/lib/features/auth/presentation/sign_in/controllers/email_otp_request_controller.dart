import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/utils/enums/otp_purpose.dart';
import '../../../domain/entities/email_otp_challenge.dart';
import '../../../domain/usecases/request_email_otp_usecase.dart';

part 'email_otp_request_controller.g.dart';

/// Sends an email code: S03 (`sign_in`), S09 step 1 (`reset_pin`) and S46
/// (`change_email`). Holds the sent challenge, or the `Failure` as an
/// `AsyncError` (`429` carries `retryAfterDelay` for the countdown).
@riverpod
class EmailOtpRequestController() extends _$EmailOtpRequestController {
  @override
  FutureOr<EmailOtpChallenge?> build() => null;

  /// Sends the code and returns true when it went out, so the page can move
  /// on to the code screen. [pin] is required only for `change_email`.
  Future<bool> request({
    required OtpPurpose purpose,
    required String email,
    String? pin,
  }) async {
    if (state.isLoading) return false;

    state = const AsyncLoading();

    final result = await ref.read(requestEmailOtpUseCaseProvider)((
      purpose: purpose,
      email: email,
      pin: pin,
    ));
    if (!ref.mounted) return result.isRight();

    state = switch (result) {
      Left(:final value) => AsyncError(value, StackTrace.current),
      Right(:final value) => AsyncData(value),
    };

    return result.isRight();
  }
}
