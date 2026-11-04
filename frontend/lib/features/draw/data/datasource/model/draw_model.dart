// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';

part 'draw_model.freezed.dart';
part 'draw_model.g.dart';

/// `DrawSlot`: one slot taking part in a draw.
@freezed
abstract class DrawSlotModel with _$DrawSlotModel {
  const factory({
    @JsonKey(name: 'slot_id') String? slotId,
    @JsonKey(name: 'slot_no') int? slotNo,
    @JsonKey(name: 'display_name') String? displayName,
  }) = _DrawSlotModel;

  factory fromJson(Map<String, dynamic> json) => _$DrawSlotModelFromJson(json);
}

/// `Draw`: a period's commitment before the draw, and everything needed to
/// recompute the result after it.
@freezed
abstract class DrawModel with _$DrawModel {
  const factory({
    @JsonKey(name: 'period_id') String? periodId,
    @JsonKey(name: 'period_no') int? periodNo,
    @JsonKey(name: 'method') String? method,
    @JsonKey(name: 'algorithm') String? algorithm,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'seed_hash') String? seedHash,
    @JsonKey(name: 'seed') String? seed,
    @JsonKey(name: 'eligible_slots') List<DrawSlotModel>? eligibleSlots,
    @JsonKey(name: 'winner') DrawSlotModel? winner,
    @JsonKey(name: 'paid_count_at_draw') int? paidCountAtDraw,
    @JsonKey(name: 'total_count_at_draw') int? totalCountAtDraw,
    @JsonKey(name: 'drawn_at') DateTime? drawnAt,
    @JsonKey(name: 'drawn_by') UserSummaryModel? drawnBy,
    @JsonKey(name: 'verification_code') String? verificationCode,
    @JsonKey(name: 'verify_url') String? verifyUrl,
  }) = _DrawModel;

  factory fromJson(Map<String, dynamic> json) => _$DrawModelFromJson(json);
}
