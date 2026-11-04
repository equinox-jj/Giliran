// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_request_model.freezed.dart';
part 'member_request_model.g.dart';

/// Body of `POST /groups/{id}/guests`.
@freezed
abstract class GuestRequestModel with _$GuestRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory({
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'phone') String? phone,
  }) = _GuestRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$GuestRequestModelFromJson(json);
}

/// Body of `PUT /groups/{id}/fixed-order`. The one-field bodies (guest
/// edit, reasons, transfer target) are plain maps in the remote data
/// source, because a guest edit must tell `phone: null` (clear) from a
/// missing phone (keep).
@freezed
abstract class FixedOrderRequestModel with _$FixedOrderRequestModel {
  @JsonSerializable(explicitToJson: true)
  const factory({
    @JsonKey(name: 'order') List<FixedOrderItemModel>? order,
  }) = _FixedOrderRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$FixedOrderRequestModelFromJson(json);
}

/// One slot's place in `FixedOrderRequest.order`.
@freezed
abstract class FixedOrderItemModel with _$FixedOrderItemModel {
  const factory({
    @JsonKey(name: 'slot_id') String? slotId,
    @JsonKey(name: 'position') int? position,
  }) = _FixedOrderItemModel;

  factory fromJson(Map<String, dynamic> json) => _$FixedOrderItemModelFromJson(json);
}
