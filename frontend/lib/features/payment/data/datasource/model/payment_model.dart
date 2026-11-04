// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';
import '../../../../member/data/datasource/model/member_model.dart';

part 'payment_model.freezed.dart';
part 'payment_model.g.dart';

/// `Payment`: one slot's dues for one period, from the payment board and
/// every payment write.
@freezed
abstract class PaymentModel with _$PaymentModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'period_id') String? periodId,
    @JsonKey(name: 'member') MemberRefModel? member,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'method') String? method,
    @JsonKey(name: 'current_proof') PaymentProofModel? currentProof,
    @JsonKey(name: 'note') String? note,
    @JsonKey(name: 'reject_reason') String? rejectReason,
    @JsonKey(name: 'paid_at') DateTime? paidAt,
    @JsonKey(name: 'reviewed_by') UserSummaryModel? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'is_mine') bool? isMine,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    /// `PaymentDetail` only: every proof, newest first.
    @JsonKey(name: 'proofs') List<PaymentProofModel>? proofs,
  }) = _PaymentModel;

  factory fromJson(Map<String, dynamic> json) => _$PaymentModelFromJson(json);
}

/// `PaymentProof`: an uploaded transfer screenshot behind a signed URL.
@freezed
abstract class PaymentProofModel with _$PaymentProofModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'url') String? url,
    @JsonKey(name: 'content_type') String? contentType,
    @JsonKey(name: 'uploaded_at') DateTime? uploadedAt,
  }) = _PaymentProofModel;

  factory fromJson(Map<String, dynamic> json) => _$PaymentProofModelFromJson(json);
}

/// `PaymentSummary`: a period's payment counts and amounts.
@freezed
abstract class PaymentSummaryModel with _$PaymentSummaryModel {
  const factory({
    @JsonKey(name: 'total_count') int? totalCount,
    @JsonKey(name: 'paid_count') int? paidCount,
    @JsonKey(name: 'pending_review_count') int? pendingReviewCount,
    @JsonKey(name: 'unpaid_count') int? unpaidCount,
    @JsonKey(name: 'rejected_count') int? rejectedCount,
    @JsonKey(name: 'collected_amount') int? collectedAmount,
    @JsonKey(name: 'expected_amount') int? expectedAmount,
  }) = _PaymentSummaryModel;

  factory fromJson(Map<String, dynamic> json) => _$PaymentSummaryModelFromJson(json);
}
