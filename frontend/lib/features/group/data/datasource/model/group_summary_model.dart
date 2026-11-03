// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_summary_model.freezed.dart';
part 'group_summary_model.g.dart';

/// `GroupSummary` from `GET /me/groups`: one card on Home and the list.
@freezed
abstract class GroupSummaryModel with _$GroupSummaryModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'period_type') String? periodType,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'my_role') String? myRole,
    @JsonKey(name: 'total_slots') int? totalSlots,
    @JsonKey(name: 'filled_slots') int? filledSlots,
    @JsonKey(name: 'current_period_no') int? currentPeriodNo,
    @JsonKey(name: 'next_due_date') String? nextDueDate,
    @JsonKey(name: 'next_draw_date') String? nextDrawDate,
    @JsonKey(name: 'my_payment_status') String? myPaymentStatus,
    @JsonKey(name: 'paid_count') int? paidCount,
    @JsonKey(name: 'pending_review_count') int? pendingReviewCount,
    @JsonKey(name: 'i_have_won') bool? iHaveWon,
  }) = _GroupSummaryModel;

  factory fromJson(Map<String, dynamic> json) => _$GroupSummaryModelFromJson(json);
}
