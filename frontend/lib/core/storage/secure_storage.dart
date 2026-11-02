import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

/// The app's encrypted key-value store (Keychain on iOS, Keystore-backed
/// storage on Android).
///
/// Every secure-storage key is declared here and nowhere else.
class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

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
}

@Riverpod(keepAlive: true)
SecureStorage secureStorage(Ref ref) =>
    const SecureStorage(FlutterSecureStorage());
