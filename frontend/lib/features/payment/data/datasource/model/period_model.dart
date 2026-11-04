// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../member/data/datasource/model/member_model.dart';
import 'payment_model.dart';

part 'period_model.freezed.dart';
part 'period_model.g.dart';

/// `Period`: one round of the cycle, from `GET /periods`.
@freezed
abstract class PeriodModel with _$PeriodModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'period_no') int? periodNo,
    @JsonKey(name: 'due_date') String? dueDate,
    @JsonKey(name: 'draw_date') String? drawDate,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'seed_hash') String? seedHash,
    @JsonKey(name: 'winner') MemberRefModel? winner,
    @JsonKey(name: 'drawn_at') DateTime? drawnAt,
    @JsonKey(name: 'verification_code') String? verificationCode,
    @JsonKey(name: 'payment_summary') PaymentSummaryModel? paymentSummary,
    @JsonKey(name: 'payout_recorded') bool? payoutRecorded,
    @JsonKey(name: 'payout_confirmed') bool? payoutConfirmed,
  }) = _PeriodModel;

  factory fromJson(Map<String, dynamic> json) => _$PeriodModelFromJson(json);
}
