import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences.g.dart';

/// Non-secret, per-device settings stored in shared preferences.
///
/// Every shared-preferences key is declared here and nowhere else.
class const Preferences(final SharedPreferencesAsync _prefs) {
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricPromptedKey = 'biometric_prompted';
  static const _languageKey = 'language';
  static const _themeModeKey = 'theme_mode';
  static const _pendingDeepLinkKey = 'pending_deep_link';
  static const _userSettingsKey = 'user_settings';
  static const _secureScreenKey = 'secure_screen';

  Future<bool> readBiometricEnabled() async => await _prefs.getBool(_biometricEnabledKey) ?? false;

  Future<void> saveBiometricEnabled(bool value) => _prefs.setBool(_biometricEnabledKey, value);

  Future<bool> readBiometricPrompted() async => await _prefs.getBool(_biometricPromptedKey) ?? false;

  Future<void> saveBiometricPrompted(bool value) => _prefs.setBool(_biometricPromptedKey, value);

  /// App language code, `id` or `en`. Defaults to `id`.
  Future<String> readLanguage() async => await _prefs.getString(_languageKey) ?? 'id';

  Future<void> saveLanguage(String value) => _prefs.setString(_languageKey, value);

  /// Theme choice, `system`, `light` or `dark`. Defaults to `system`.
  Future<String> readThemeMode() async => await _prefs.getString(_themeModeKey) ?? 'system';

  Future<void> saveThemeMode(String value) => _prefs.setString(_themeModeKey, value);

  /// An invite or claim link opened while signed out, resumed after
  /// sign-in. Null when there is none.
  Future<String?> readPendingDeepLink() => _prefs.getString(_pendingDeepLinkKey);

  /// Stores [value], or clears the pending link when it is null.
  Future<void> savePendingDeepLink(String? value) =>
      value == null ? _prefs.remove(_pendingDeepLinkKey) : _prefs.setString(_pendingDeepLinkKey, value);

  /// The signed-in account's last known settings as JSON, shown on Settings
  /// before the server answers. Null when none are saved.
  Future<String?> readUserSettings() => _prefs.getString(_userSettingsKey);

  /// Stores [value], or clears the saved settings when it is null.
  Future<void> saveUserSettings(String? value) =>
      value == null ? _prefs.remove(_userSettingsKey) : _prefs.setString(_userSettingsKey, value);

  /// Whether S47 "Sembunyikan layar di app terbaru" is on (Android
  /// `FLAG_SECURE`). Off by default.
  Future<bool> readSecureScreen() async => await _prefs.getBool(_secureScreenKey) ?? false;

  Future<void> saveSecureScreen(bool value) => _prefs.setBool(_secureScreenKey, value);
}

@Riverpod(keepAlive: true)
Preferences preferences(Ref ref) => Preferences(SharedPreferencesAsync());
