// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../group/data/datasource/model/group_model.dart';
import 'member_model.dart';

part 'leave_request_model.freezed.dart';
part 'leave_request_model.g.dart';

/// `LeaveRequest` from the leave-request endpoints.
@freezed
abstract class LeaveRequestModel with _$LeaveRequestModel {
  const factory({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'member') MemberRefModel? member,
    @JsonKey(name: 'reason') String? reason,
    @JsonKey(name: 'status') String? status,
    @JsonKey(name: 'reviewed_by') UserSummaryModel? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _LeaveRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$LeaveRequestModelFromJson(json);
}
