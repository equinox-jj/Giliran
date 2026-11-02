// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../core/utils/enums/otp_purpose.dart';

part 'email_otp_request_model.freezed.dart';
part 'email_otp_request_model.g.dart';

/// Body of `POST /auth/email/otp`. [pin] is sent only for `change_email`.
@freezed
abstract class EmailOtpRequestModel with _$EmailOtpRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory({
    @JsonKey(name: 'purpose') OtpPurpose? purpose,
    @JsonKey(name: 'email') String? email,
    @JsonKey(name: 'device_name') String? deviceName,
    @JsonKey(name: 'device_platform') String? devicePlatform,
    @JsonKey(name: 'fcm_token') String? fcmToken,
    @JsonKey(name: 'pin') String? pin,
  }) = _EmailOtpRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$EmailOtpRequestModelFromJson(json);
}
