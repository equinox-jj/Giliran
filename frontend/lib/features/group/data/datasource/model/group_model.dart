// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_model.freezed.dart';
part 'group_model.g.dart';

/// `Group` from `GroupEnvelope` (`GET`/`PATCH /groups/{id}`, create, close,
/// payment info).
@freezed
abstract class GroupModel with _$GroupModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'pot_amount') int? potAmount,
    @JsonKey(name: 'period_type') String? periodType,
    @JsonKey(name: 'total_slots') int? totalSlots,
    @JsonKey(name: 'filled_slots') int? filledSlots,
    @JsonKey(name: 'draw_method') String? drawMethod,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'reminder_days_before') int? reminderDaysBefore,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'organizer') UserSummaryModel? organizer,
    @JsonKey(name: 'my_role') String? myRole,
    @JsonKey(name: 'my_member_id') String? myMemberId,
    @JsonKey(name: 'invite') InviteModel? invite,
    @JsonKey(name: 'payment_info') PaymentInfoModel? paymentInfo,
    @JsonKey(name: 'current_period_id') String? currentPeriodId,
    @JsonKey(name: 'started_at') DateTime? startedAt,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'closed_at') DateTime? closedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _GroupModel;

  factory fromJson(Map<String, dynamic> json) => _$GroupModelFromJson(json);
}

/// `UserSummary`: the organizer on a group.
@freezed
abstract class UserSummaryModel with _$UserSummaryModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'name') String? name,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
  }) = _UserSummaryModel;

  factory fromJson(Map<String, dynamic> json) => _$UserSummaryModelFromJson(json);
}

/// `Invite`, sent to organizers and co-organizers only.
@freezed
abstract class InviteModel with _$InviteModel {
  const factory({
    @JsonKey(name: 'invite_code') String? inviteCode,
    @JsonKey(name: 'invite_url') String? inviteUrl,
  }) = _InviteModel;

  factory fromJson(Map<String, dynamic> json) => _$InviteModelFromJson(json);
}

/// `PaymentInfo`: where members transfer their dues.
@freezed
abstract class PaymentInfoModel with _$PaymentInfoModel {
  const factory({
    @JsonKey(name: 'bank_name') String? bankName,
    @JsonKey(name: 'account_number') String? accountNumber,
    @JsonKey(name: 'account_holder') String? accountHolder,
    @JsonKey(name: 'qris_image_url') String? qrisImageUrl,
    @JsonKey(name: 'qris_merchant_name') String? qrisMerchantName,
  }) = _PaymentInfoModel;

  factory fromJson(Map<String, dynamic> json) => _$PaymentInfoModelFromJson(json);
}
