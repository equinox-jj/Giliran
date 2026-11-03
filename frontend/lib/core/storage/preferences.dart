import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences.g.dart';

/// Non-secret, per-device settings stored in shared preferences.
///
/// Every shared-preferences key is declared here and nowhere else.
class const Preferences(final SharedPreferencesAsync _prefs) {
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricPromptedKey = 'biometric_prompted';

  Future<bool> readBiometricEnabled() async => await _prefs.getBool(_biometricEnabledKey) ?? false;

  Future<void> saveBiometricEnabled(bool value) => _prefs.setBool(_biometricEnabledKey, value);

  Future<bool> readBiometricPrompted() async => await _prefs.getBool(_biometricPromptedKey) ?? false;

  Future<void> saveBiometricPrompted(bool value) => _prefs.setBool(_biometricPromptedKey, value);
}

@Riverpod(keepAlive: true)
Preferences preferences(Ref ref) => Preferences(SharedPreferencesAsync());
