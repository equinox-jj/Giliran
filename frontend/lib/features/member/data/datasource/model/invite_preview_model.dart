// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';

part 'invite_preview_model.freezed.dart';
part 'invite_preview_model.g.dart';

/// `InvitePreview` from `GET /invites/{code}`.
@freezed
abstract class InvitePreviewModel with _$InvitePreviewModel {
  const factory({
    @JsonKey(name: 'group_id') String? groupId,
    @JsonKey(name: 'group_name') String? groupName,
    @JsonKey(name: 'organizer') UserSummaryModel? organizer,
    @JsonKey(name: 'amount') int? amount,
    @JsonKey(name: 'period_type') String? periodType,
    @JsonKey(name: 'total_slots') int? totalSlots,
    @JsonKey(name: 'filled_slots') int? filledSlots,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'can_join') bool? canJoin,
    @JsonKey(name: 'already_member') bool? alreadyMember,
  }) = _InvitePreviewModel;

  factory fromJson(Map<String, dynamic> json) => _$InvitePreviewModelFromJson(json);
}
