import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/otp_purpose.dart';

part 'email_otp_challenge.freezed.dart';

/// A sent email code waiting to be verified: what the email code screen
/// (S04/S09) needs to show the masked address, the countdown and the
/// attempts left.
@freezed
abstract class EmailOtpChallenge with _$EmailOtpChallenge {
  const factory EmailOtpChallenge({
    String? id,
    OtpPurpose? purpose,
    String? emailMasked,
    int? codeLength,
    DateTime? expiresAt,
    DateTime? resendAvailableAt,
    int? attemptsRemaining,
  }) = _EmailOtpChallenge;
}

/// An unfinished code request kept on the device, so S04 can resume after
/// the app is closed. [email] is the full address the user typed.
@freezed
abstract class PendingOtp with _$PendingOtp {
  const factory PendingOtp({
    String? email,
    EmailOtpChallenge? challenge,
  }) = _PendingOtp;
}
