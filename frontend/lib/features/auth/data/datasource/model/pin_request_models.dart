import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_request_models.freezed.dart';
part 'pin_request_models.g.dart';

/// Body of `POST /auth/pin/verify` (unlock).
@freezed
abstract class PinRequestModel with _$PinRequestModel {
  const factory PinRequestModel({
    @JsonKey(name: 'pin') String? pin,
  }) = _PinRequestModel;

  factory PinRequestModel.fromJson(Map<String, dynamic> json) => _$PinRequestModelFromJson(json);
}

/// Body of `POST /auth/pin` (first PIN, S06).
@freezed
abstract class SetPinRequestModel with _$SetPinRequestModel {
  const factory SetPinRequestModel({
    @JsonKey(name: 'pin') String? pin,
    @JsonKey(name: 'pin_confirmation') String? pinConfirmation,
  }) = _SetPinRequestModel;

  factory SetPinRequestModel.fromJson(Map<String, dynamic> json) => _$SetPinRequestModelFromJson(json);
}

/// Body of `PUT /auth/pin` (change PIN, S45).
@freezed
abstract class ChangePinRequestModel with _$ChangePinRequestModel {
  const factory ChangePinRequestModel({
    @JsonKey(name: 'current_pin') String? currentPin,
    @JsonKey(name: 'new_pin') String? newPin,
    @JsonKey(name: 'new_pin_confirmation') String? newPinConfirmation,
  }) = _ChangePinRequestModel;

  factory ChangePinRequestModel.fromJson(Map<String, dynamic> json) => _$ChangePinRequestModelFromJson(json);
}
