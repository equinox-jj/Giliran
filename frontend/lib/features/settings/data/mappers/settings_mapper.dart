import '../../domain/entities/user_settings.dart';
import '../datasource/model/user_settings_model.dart';

extension UserSettingsModelMapper on UserSettingsModel {
  UserSettings toEntity() => UserSettings(
    language: language,
    notifyPaymentReminders: notifyPaymentReminders,
    notifyDrawResults: notifyDrawResults,
    notifyGroupActivity: notifyGroupActivity,
  );
}

extension UserSettingsPatchMapper on UserSettingsPatch {
  UpdateSettingsRequestModel toRequest() => UpdateSettingsRequestModel(
    language: language,
    notifyPaymentReminders: notifyPaymentReminders,
    notifyDrawResults: notifyDrawResults,
    notifyGroupActivity: notifyGroupActivity,
  );
}
