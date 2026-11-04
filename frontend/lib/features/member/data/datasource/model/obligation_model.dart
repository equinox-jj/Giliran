// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'member_model.dart';

part 'obligation_model.freezed.dart';
part 'obligation_model.g.dart';

/// `Obligation` from `GET /groups/{id}/obligations`: what a past winner
/// still owes.
@freezed
abstract class ObligationModel with _$ObligationModel {
  const factory({
    @JsonKey(name: 'member') MemberRefModel? member,
    @JsonKey(name: 'won_period_no') int? wonPeriodNo,
    @JsonKey(name: 'remaining_count') int? remainingCount,
    @JsonKey(name: 'remaining_amount') int? remainingAmount,
    @JsonKey(name: 'overdue_count') int? overdueCount,
    @JsonKey(name: 'overdue_amount') int? overdueAmount,
  }) = _ObligationModel;

  factory fromJson(Map<String, dynamic> json) => _$ObligationModelFromJson(json);
}
