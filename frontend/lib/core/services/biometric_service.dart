import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/enums/biometric_kind.dart';
import '../utils/logger/app_logger.dart';

part 'biometric_service.g.dart';

/// Thin wrapper over `local_auth` for biometric unlock (S07, S08).
///
/// The PIN is always the fallback, so every platform failure ends as "not
/// available" or "not authenticated" instead of an error.
class const BiometricService(final LocalAuthentication _auth) {
  static const _tag = 'biometric';

  /// The enrolled biometric the app can use, or null when there is none.
  /// Face wins over fingerprint when a device has both.
  Future<BiometricKind?> availableKind() async {
    try {
      if (!await _auth.canCheckBiometrics) return null;
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.isNotEmpty) return BiometricKind.fingerprint;
      return null;
    } on Exception catch (e) {
      AppLogger.w('availableKind failed: $e', tag: _tag);
      return null;
    }
  }

  /// Shows the system biometric prompt with [reason]. True only when the user
  /// passed it; cancel, lockout and errors all return false.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      AppLogger.w('authenticate failed: ${e.code.name}', tag: _tag);
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
BiometricService biometricService(Ref ref) => BiometricService(LocalAuthentication());
