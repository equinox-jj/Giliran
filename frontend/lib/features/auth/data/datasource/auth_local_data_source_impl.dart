import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/preferences.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../profile/data/datasource/model/profile_model.dart';
import 'auth_local_data_source.dart';
import 'model/email_otp_challenge_model.dart';
import 'model/token_pair_model.dart';

part 'auth_local_data_source_impl.g.dart';

class AuthLocalDataSourceImpl({
  required SecureStorage secureStorage,
  required Preferences preferences,
}) with BaseLocalDataSource implements AuthLocalDataSource {
  this : _secure = secureStorage, _prefs = preferences;

  final SecureStorage _secure;
  final Preferences _prefs;

  @override
  Future<void> saveTokens(TokenPairModel tokens) => safeCacheCall(() async {
    final access = tokens.accessToken;
    final refresh = tokens.refreshToken;
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      throw const CacheException('Token pair is incomplete');
    }
    await _secure.saveTokens(accessToken: access, refreshToken: refresh);
  });

  @override
  Future<bool> hasRefreshToken() => safeCacheCall(() async {
    final token = await _secure.readRefreshToken();
    return token != null && token.isNotEmpty;
  });

  @override
  Future<ProfileDataModel?> readCurrentUser() => safeCacheCall(
    () async => _decode(
      await _secure.readCurrentUser(),
      ProfileDataModel.fromJson,
      onCorrupt: _secure.clearCurrentUser,
    ),
  );

  @override
  Future<void> saveCurrentUser(ProfileDataModel user) => safeCacheCall(
    () => _secure.saveCurrentUser(jsonEncode(user.toJson())),
  );

  @override
  Future<PendingOtpModel?> readPendingOtp() => safeCacheCall(
    () async => _decode(
      await _secure.readPendingOtp(),
      PendingOtpModel.fromJson,
      onCorrupt: _secure.clearPendingOtp,
    ),
  );

  @override
  Future<void> savePendingOtp(PendingOtpModel pending) => safeCacheCall(
    () => _secure.savePendingOtp(jsonEncode(pending.toJson())),
  );

  @override
  Future<void> clearPendingOtp() => safeCacheCall(_secure.clearPendingOtp);

  // Future.wait lets every delete finish even if one fails, so a failure
  // can't leave the other values behind; the first error is rethrown.
  @override
  Future<void> clearSession() => safeCacheCall(
    () => Future.wait([
      _secure.clearTokens(),
      _secure.clearCurrentUser(),
      _secure.clearPendingOtp(),
    ]),
  );

  @override
  Future<bool> readBiometricEnabled() => safeCacheCall(
    _prefs.readBiometricEnabled,
  );

  @override
  Future<void> saveBiometricEnabled(bool enabled) => safeCacheCall(
    () => _prefs.saveBiometricEnabled(enabled),
  );

  @override
  Future<bool> readBiometricPrompted() => safeCacheCall(
    _prefs.readBiometricPrompted,
  );

  @override
  Future<void> saveBiometricPrompted(bool prompted) => safeCacheCall(
    () => _prefs.saveBiometricPrompted(prompted),
  );

  /// Decodes a cached JSON value. A corrupt value is deleted and read as
  /// null, so a bad write can't block the launch gate.
  Future<T?> _decode<T>(
    String? raw,
    T Function(Map<String, dynamic> json) fromJson, {
    required Future<void> Function() onCorrupt,
  }) async {
    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await onCorrupt();
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      await onCorrupt();
      return null;
    }
    return fromJson(decoded);
  }
}

@Riverpod(keepAlive: true)
AuthLocalDataSource authLocalDataSource(Ref ref) => AuthLocalDataSourceImpl(
  secureStorage: ref.watch(secureStorageProvider),
  preferences: ref.watch(preferencesProvider),
);
