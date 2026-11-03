import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/enums/otp_purpose.dart';

part 'email_otp_challenge.freezed.dart';

@freezed
abstract class EmailOtpChallenge with _$EmailOtpChallenge {
  const factory({
    String? id,
    OtpPurpose? purpose,
    String? emailMasked,
    int? codeLength,
    DateTime? expiresAt,
    DateTime? resendAvailableAt,
    int? attemptsRemaining,
  }) = _EmailOtpChallenge;
}

@freezed
abstract class PendingOtp with _$PendingOtp {
  const factory({
    String? email,
    EmailOtpChallenge? challenge,
  }) = _PendingOtp;
}
