// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';

part 'member_model.freezed.dart';
part 'member_model.g.dart';

/// `Member` from the members, guests, join, claim and fixed-order
/// endpoints.
@freezed
abstract class MemberModel with _$MemberModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'user') UserSummaryModel? user,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'is_guest') bool? isGuest,
    @JsonKey(name: 'guest_phone') String? guestPhone,
    @JsonKey(name: 'role') String? role,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'slot_id') String? slotId,
    @JsonKey(name: 'slot_no') int? slotNo,
    @JsonKey(name: 'fixed_order_position') int? fixedOrderPosition,
    @JsonKey(name: 'has_won') bool? hasWon,
    @JsonKey(name: 'won_period_no') int? wonPeriodNo,
    @JsonKey(name: 'joined_at') DateTime? joinedAt,
  }) = _MemberModel;

  factory fromJson(Map<String, dynamic> json) => _$MemberModelFromJson(json);
}

/// `MemberRef`: the compact member inside leave requests, transfers and
/// obligations.
@freezed
abstract class MemberRefModel with _$MemberRefModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'is_guest') bool? isGuest,
    @JsonKey(name: 'slot_no') int? slotNo,
  }) = _MemberRefModel;

  factory fromJson(Map<String, dynamic> json) => _$MemberRefModelFromJson(json);
}
