// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';
import '../../../../member/data/datasource/model/member_model.dart';

part 'activity_entry_model.freezed.dart';
part 'activity_entry_model.g.dart';

/// `ActivityEntry` from `GET /groups/{id}/activity`.
@freezed
abstract class ActivityEntryModel with _$ActivityEntryModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'action') String? action,
    @JsonKey(name: 'entity_type') String? entityType,
    @JsonKey(name: 'entity_id') String? entityId,
    @JsonKey(name: 'actor') UserSummaryModel? actor,
    @JsonKey(name: 'subject') MemberRefModel? subject,
    @JsonKey(name: 'before') Map<String, dynamic>? before,
    @JsonKey(name: 'after') Map<String, dynamic>? after,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _ActivityEntryModel;

  factory fromJson(Map<String, dynamic> json) => _$ActivityEntryModelFromJson(json);
}
