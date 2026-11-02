// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'email_otp_verify_request_model.freezed.dart';
part 'email_otp_verify_request_model.g.dart';

/// Body of `POST /auth/email/otp/{id}/verify`. Which fields are set depends
/// on the purpose: `code` alone, `code` + `pin` (existing account), or
/// `code` + `new_pin` + `new_pin_confirmation` (forgot PIN).
@freezed
abstract class EmailOtpVerifyRequestModel with _$EmailOtpVerifyRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory EmailOtpVerifyRequestModel({
    @JsonKey(name: 'code') String? code,
    @JsonKey(name: 'pin') String? pin,
    @JsonKey(name: 'new_pin') String? newPin,
    @JsonKey(name: 'new_pin_confirmation') String? newPinConfirmation,
  }) = _EmailOtpVerifyRequestModel;

  factory EmailOtpVerifyRequestModel.fromJson(Map<String, dynamic> json) => _$EmailOtpVerifyRequestModelFromJson(json);
}
