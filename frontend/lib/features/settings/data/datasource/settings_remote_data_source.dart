import 'model/user_settings_model.dart';

/// The `/me/settings` endpoints. Every method throws a typed `AppException`
/// on failure.
abstract interface class SettingsRemoteDataSource() {
  /// `GET /me/settings`.
  Future<UserSettingsModel> getSettings();

  /// `PATCH /me/settings` with only the fields to change.
  Future<UserSettingsModel> updateSettings(UpdateSettingsRequestModel body);
}
