import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

/// The app's encrypted key-value store (Keychain on iOS, Keystore-backed
/// storage on Android).
///
/// Every secure-storage key is declared here and nowhere else. Values are raw
/// strings; callers encode and decode JSON themselves.
class const SecureStorage(final FlutterSecureStorage _storage) {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _pendingOtpKey = 'pending_otp';
  static const _currentUserKey = 'current_user';

  /// The stored access token, or null when signed out.
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  /// The stored refresh token, or null when signed out.
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Persists a new token pair.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Removes both tokens, leaving any other secure values in place.
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// The unfinished sign-in code request (JSON), kept so the code screen can
  /// be resumed after the app is closed (design 10.2).
  Future<String?> readPendingOtp() => _storage.read(key: _pendingOtpKey);

  Future<void> savePendingOtp(String json) => _storage.write(key: _pendingOtpKey, value: json);

  Future<void> clearPendingOtp() => _storage.delete(key: _pendingOtpKey);

  /// The signed-in user's profile (JSON), cached for the lock screen greeting
  /// and the launch redirect rules.
  Future<String?> readCurrentUser() => _storage.read(key: _currentUserKey);

  Future<void> saveCurrentUser(String json) => _storage.write(key: _currentUserKey, value: json);

  Future<void> clearCurrentUser() => _storage.delete(key: _currentUserKey);
}

@Riverpod(keepAlive: true)
SecureStorage secureStorage(Ref ref) => const SecureStorage(FlutterSecureStorage());
