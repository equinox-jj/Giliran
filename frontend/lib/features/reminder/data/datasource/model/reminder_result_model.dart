// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../member/data/datasource/model/member_model.dart';

part 'reminder_result_model.freezed.dart';
part 'reminder_result_model.g.dart';

/// A member the push reminder skipped, and why.
@freezed
abstract class SkippedReminderModel with _$SkippedReminderModel {
  const factory({
    @JsonKey(name: 'member') MemberRefModel? member,
    @JsonKey(name: 'reason') String? reason,
    @JsonKey(name: 'whatsapp_phone') String? whatsappPhone,
  }) = _SkippedReminderModel;

  factory fromJson(Map<String, dynamic> json) => _$SkippedReminderModelFromJson(json);
}

/// `ReminderResult`: how many pushes went out and who was skipped.
@freezed
abstract class ReminderResultModel with _$ReminderResultModel {
  const factory({
    @JsonKey(name: 'sent_count') int? sentCount,
    @JsonKey(name: 'skipped') List<SkippedReminderModel>? skipped,
  }) = _ReminderResultModel;

  factory fromJson(Map<String, dynamic> json) => _$ReminderResultModelFromJson(json);
}
