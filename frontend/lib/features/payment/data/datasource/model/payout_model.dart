// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';
import '../../../../member/data/datasource/model/member_model.dart';

part 'payout_model.freezed.dart';
part 'payout_model.g.dart';

/// `Payout`: the record that a period's pot went to its winner.
@freezed
abstract class PayoutModel with _$PayoutModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'period_id') String? periodId,
    @JsonKey(name: 'winner') MemberRefModel? winner,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'proof_url') String? proofUrl,
    @JsonKey(name: 'note') String? note,
    @JsonKey(name: 'recorded_by') UserSummaryModel? recordedBy,
    @JsonKey(name: 'recorded_at') DateTime? recordedAt,
    @JsonKey(name: 'confirmed_at') DateTime? confirmedAt,
  }) = _PayoutModel;

  factory fromJson(Map<String, dynamic> json) => _$PayoutModelFromJson(json);
}
