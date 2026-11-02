// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/utils/enums/otp_purpose.dart';

part 'email_otp_challenge_model.freezed.dart';
part 'email_otp_challenge_model.g.dart';

/// JSON shape of `EmailOtpChallenge`, returned when a code is requested or
/// resent. Also cached in secure storage so S04 can be resumed.
@freezed
abstract class EmailOtpChallengeModel with _$EmailOtpChallengeModel {
  const factory EmailOtpChallengeModel({
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

  factory EmailOtpChallengeModel.fromJson(Map<String, dynamic> json) => _$EmailOtpChallengeModelFromJson(json);
}

/// An unfinished code request saved on the device: the challenge plus the
/// full email the user typed, which the API only returns masked. Lets S04
/// resume after the app is closed (design 10.2).
@freezed
abstract class PendingOtpModel with _$PendingOtpModel {
  @JsonSerializable(explicitToJson: true)
  const factory PendingOtpModel({
    @JsonKey(name: 'email') String? email,
    @JsonKey(name: 'challenge') EmailOtpChallengeModel? challenge,
  }) = _PendingOtpModel;

  factory PendingOtpModel.fromJson(Map<String, dynamic> json) => _$PendingOtpModelFromJson(json);
}
