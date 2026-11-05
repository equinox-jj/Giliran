import 'model/user_settings_model.dart';

/// Device-only data behind Settings. Throws `CacheException` on
/// failure.
abstract interface class SettingsLocalDataSource() {
  /// The last account settings saved on this device, or null when there are
  /// none (or the saved value is unreadable).
  Future<UserSettingsModel?> readSettings();

  /// Saves [settings] so Settings opens with them before the server answers.
  Future<void> saveSettings(UserSettingsModel settings);

  /// Empties the downloaded image cache (avatars, proofs, QRIS) and the
  /// in-memory decoded images.
  Future<void> clearImageCache();
}
