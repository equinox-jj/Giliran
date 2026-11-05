import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_settings.freezed.dart';

/// The account's notification and language settings.
@freezed
abstract class UserSettings with _$UserSettings {
  const factory({
    /// `id` or `en`.
    String? language,
    bool? notifyPaymentReminders,
    bool? notifyDrawResults,
    bool? notifyGroupActivity,
  }) = _UserSettings;
}

/// The settings to change; a null field is left as it is.
@freezed
abstract class UserSettingsPatch with _$UserSettingsPatch {
  const factory({
    String? language,
    bool? notifyPaymentReminders,
    bool? notifyDrawResults,
    bool? notifyGroupActivity,
  }) = _UserSettingsPatch;
}
