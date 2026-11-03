// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_request_model.freezed.dart';
part 'group_request_model.g.dart';

/// Body of `POST /groups`.
@freezed
abstract class CreateGroupRequestModel with _$CreateGroupRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory({
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'period_type') String? periodType,
    @JsonKey(name: 'total_slots') int? totalSlots,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'draw_method') String? drawMethod,
    @JsonKey(name: 'reminder_days_before') int? reminderDaysBefore,
  }) = _CreateGroupRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$CreateGroupRequestModelFromJson(json);
}

/// Body of `PATCH /groups/{id}`. Unset fields are left out, so only the
/// changed settings are sent.
@freezed
abstract class UpdateGroupRequestModel with _$UpdateGroupRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory({
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'period_type') String? periodType,
    @JsonKey(name: 'total_slots') int? totalSlots,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'draw_method') String? drawMethod,
    @JsonKey(name: 'reminder_days_before') int? reminderDaysBefore,
  }) = _UpdateGroupRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$UpdateGroupRequestModelFromJson(json);
}

/// Body of `PUT /groups/{id}/payment-info`.
@freezed
abstract class PaymentInfoRequestModel with _$PaymentInfoRequestModel {
  const factory({
    @JsonKey(name: 'bank_name') String? bankName,
    @JsonKey(name: 'account_number') String? accountNumber,
    @JsonKey(name: 'account_holder') String? accountHolder,
  }) = _PaymentInfoRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$PaymentInfoRequestModelFromJson(json);
}
