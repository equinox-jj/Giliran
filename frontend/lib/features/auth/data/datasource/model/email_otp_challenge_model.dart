// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/utils/enums/otp_purpose.dart';

part 'email_otp_challenge_model.freezed.dart';
part 'email_otp_challenge_model.g.dart';

@freezed
abstract class EmailOtpChallengeModel with _$EmailOtpChallengeModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(
      name: 'purpose',
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    OtpPurpose? purpose,
    @JsonKey(name: 'email_masked') String? emailMasked,
    @JsonKey(name: 'code_length') int? codeLength,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'resend_available_at') DateTime? resendAvailableAt,
    @JsonKey(name: 'attempts_remaining') int? attemptsRemaining,
  }) = _EmailOtpChallengeModel;

  factory fromJson(Map<String, dynamic> json) => _$EmailOtpChallengeModelFromJson(json);
}

@freezed
abstract class PendingOtpModel with _$PendingOtpModel {
  @JsonSerializable(explicitToJson: true)
  const factory({
    @JsonKey(name: 'email') String? email,
    @JsonKey(name: 'challenge') EmailOtpChallengeModel? challenge,
  }) = _PendingOtpModel;

  factory fromJson(Map<String, dynamic> json) => _$PendingOtpModelFromJson(json);
}
