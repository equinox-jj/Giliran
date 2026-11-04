import 'package:giliran/core/storage/preferences.dart';

/// In-memory [Preferences] for tests.
class FakePreferences() implements Preferences {
  bool biometricEnabled = false;
  bool biometricPrompted = false;
  String language = 'id';
  String themeMode = 'system';
  String? pendingDeepLink;

  @override
  Future<bool> readBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> saveBiometricEnabled(bool value) async => biometricEnabled = value;

  @override
  Future<bool> readBiometricPrompted() async => biometricPrompted;

  @override
  Future<void> saveBiometricPrompted(bool value) async => biometricPrompted = value;

  @override
  Future<String> readLanguage() async => language;

  @override
  Future<void> saveLanguage(String value) async => language = value;

  @override
  Future<String> readThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(String value) async => themeMode = value;

  @override
  Future<String?> readPendingDeepLink() async => pendingDeepLink;

  @override
  Future<void> savePendingDeepLink(String? value) async => pendingDeepLink = value;
}
