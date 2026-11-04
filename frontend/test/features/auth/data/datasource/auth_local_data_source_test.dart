import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/storage/secure_storage.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/data/datasource/auth_local_data_source_impl.dart';
import 'package:giliran/features/auth/data/datasource/model/email_otp_challenge_model.dart';
import 'package:giliran/features/auth/data/datasource/model/token_pair_model.dart';
import 'package:giliran/features/profile/data/datasource/model/profile_model.dart';

import '../../../../helpers/fake_preferences.dart';

/// In-memory [SecureStorage]; [throwOnRead] simulates a Keystore failure.
class _FakeSecureStorage() implements SecureStorage {
  String? access;
  String? refresh;
  String? pendingOtp;
  String? currentUser;
  bool throwOnRead = false;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async {
    if (throwOnRead) throw Exception('keystore unavailable');
    return refresh;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }

  @override
  Future<String?> readPendingOtp() async => pendingOtp;

  @override
  Future<void> savePendingOtp(String json) async => pendingOtp = json;

  @override
  Future<void> clearPendingOtp() async => pendingOtp = null;

  @override
  Future<String?> readCurrentUser() async => currentUser;

  @override
  Future<void> saveCurrentUser(String json) async => currentUser = json;

  @override
  Future<void> clearCurrentUser() async => currentUser = null;
}

void main() {
  late _FakeSecureStorage secure;
  late FakePreferences prefs;
  late AuthLocalDataSourceImpl dataSource;

  setUp(() {
    secure = _FakeSecureStorage();
    prefs = FakePreferences();
    dataSource = AuthLocalDataSourceImpl(
      secureStorage: secure,
      preferences: prefs,
    );
  });

  group('tokens', () {
    test('saveTokens stores both tokens', () async {
      // Arrange
      const tokens = TokenPairModel(accessToken: 'a', refreshToken: 'r');

      // Act
      await dataSource.saveTokens(tokens);

      // Assert
      expect(secure.access, 'a');
      expect(secure.refresh, 'r');
      expect(await dataSource.hasRefreshToken(), isTrue);
    });

    test('saveTokens throws CacheException when a token is missing', () async {
      // Arrange
      const tokens = TokenPairModel(accessToken: 'a');

      // Act
      final call = dataSource.saveTokens(tokens);

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
      expect(secure.access, isNull);
    });

    test('hasRefreshToken is false when none is stored', () async {
      // Arrange
      secure.refresh = '';

      // Act
      final hasToken = await dataSource.hasRefreshToken();

      // Assert
      expect(hasToken, isFalse);
    });

    test('wraps storage failures in CacheException', () async {
      // Arrange
      secure.throwOnRead = true;

      // Act
      final call = dataSource.hasRefreshToken();

      // Assert
      await expectLater(call, throwsA(isA<CacheException>()));
    });
  });

  group('current user', () {
    test('round-trips the cached user', () async {
      // Arrange
      final user = ProfileDataModel(
        id: 'user-1',
        email: 'joshua@email.com',
        name: 'Joshua',
        pinSet: true,
        createdAt: DateTime.utc(2026, 11, 2, 8),
      );

      // Act
      await dataSource.saveCurrentUser(user);
      final read = await dataSource.readCurrentUser();

      // Assert
      expect(read, user);
    });

    test('reads null when nothing is cached', () async {
      // Arrange
      secure.currentUser = null;

      // Act
      final read = await dataSource.readCurrentUser();

      // Assert
      expect(read, isNull);
    });

    test('drops a corrupt cached user and reads null', () async {
      // Arrange
      secure.currentUser = '{not json';

      // Act
      final read = await dataSource.readCurrentUser();

      // Assert
      expect(read, isNull);
      expect(secure.currentUser, isNull);
    });

    test('drops a cached value that is not a JSON object', () async {
      // Arrange
      secure.currentUser = '[1, 2]';

      // Act
      final read = await dataSource.readCurrentUser();

      // Assert
      expect(read, isNull);
      expect(secure.currentUser, isNull);
    });
  });

  group('pending code request', () {
    test('round-trips the email and challenge', () async {
      // Arrange
      final pending = PendingOtpModel(
        email: 'joshua@email.com',
        challenge: EmailOtpChallengeModel(
          id: 'otp-1',
          purpose: OtpPurpose.signIn,
          emailMasked: 'jo•••••@email.com',
          codeLength: 6,
          expiresAt: DateTime.utc(2026, 11, 2, 8, 10),
          resendAvailableAt: DateTime.utc(2026, 11, 2, 8, 1),
          attemptsRemaining: 5,
        ),
      );

      // Act
      await dataSource.savePendingOtp(pending);
      final read = await dataSource.readPendingOtp();

      // Assert
      expect(read, pending);
    });

    test('clearPendingOtp removes it', () async {
      // Arrange
      await dataSource.savePendingOtp(
        const PendingOtpModel(email: 'joshua@email.com'),
      );

      // Act
      await dataSource.clearPendingOtp();

      // Assert
      expect(await dataSource.readPendingOtp(), isNull);
    });
  });

  test('clearSession removes tokens, user, pending request and saved settings', () async {
    // Arrange
    secure
      ..access = 'a'
      ..refresh = 'r'
      ..currentUser = '{}'
      ..pendingOtp = '{}';
    prefs
      ..biometricEnabled = true
      ..userSettings = '{}';

    // Act
    await dataSource.clearSession();

    // Assert
    expect(secure.access, isNull);
    expect(secure.refresh, isNull);
    expect(secure.currentUser, isNull);
    expect(secure.pendingOtp, isNull);
    expect(prefs.userSettings, isNull, reason: 'account settings leave with the account');
    expect(prefs.biometricEnabled, isTrue, reason: 'device setting stays');
  });

  group('biometric flags', () {
    test('default to false', () async {
      // Arrange
      // Fresh preferences.

      // Act
      final enabled = await dataSource.readBiometricEnabled();
      final prompted = await dataSource.readBiometricPrompted();

      // Assert
      expect(enabled, isFalse);
      expect(prompted, isFalse);
    });

    test('save and read back', () async {
      // Arrange
      // Fresh preferences.

      // Act
      await dataSource.saveBiometricEnabled(true);
      await dataSource.saveBiometricPrompted(true);

      // Assert
      expect(await dataSource.readBiometricEnabled(), isTrue);
      expect(await dataSource.readBiometricPrompted(), isTrue);
    });
  });
}
