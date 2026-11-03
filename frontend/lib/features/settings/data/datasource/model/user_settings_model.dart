// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings_model.freezed.dart';
part 'user_settings_model.g.dart';

/// `UserSettings` from `GET`/`PATCH /me/settings`.
@freezed
abstract class UserSettingsModel with _$UserSettingsModel {
  const factory({
    @JsonKey(name: 'language') String? language,
    @JsonKey(name: 'notify_payment_reminders') bool? notifyPaymentReminders,
    @JsonKey(name: 'notify_draw_results') bool? notifyDrawResults,
    @JsonKey(name: 'notify_group_activity') bool? notifyGroupActivity,
  }) = _UserSettingsModel;

  factory fromJson(Map<String, dynamic> json) => _$UserSettingsModelFromJson(json);
}

/// Body of `PATCH /me/settings`. Unset fields are left out, so only the
/// changed setting is sent.
@freezed
abstract class UpdateSettingsRequestModel with _$UpdateSettingsRequestModel {
  @JsonSerializable(includeIfNull: false)
  const factory({
    @JsonKey(name: 'language') String? language,
    @JsonKey(name: 'notify_payment_reminders') bool? notifyPaymentReminders,
    @JsonKey(name: 'notify_draw_results') bool? notifyDrawResults,
    @JsonKey(name: 'notify_group_activity') bool? notifyGroupActivity,
  }) = _UpdateSettingsRequestModel;

  factory fromJson(Map<String, dynamic> json) => _$UpdateSettingsRequestModelFromJson(json);
}
