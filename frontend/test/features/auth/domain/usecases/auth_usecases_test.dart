import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/usecase/usecase.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/domain/repositories/auth_repository.dart';
import 'package:giliran/features/auth/domain/usecases/change_pin.dart';
import 'package:giliran/features/auth/domain/usecases/get_biometric_enabled.dart';
import 'package:giliran/features/auth/domain/usecases/get_current_user.dart';
import 'package:giliran/features/auth/domain/usecases/get_pending_otp.dart';
import 'package:giliran/features/auth/domain/usecases/has_session.dart';
import 'package:giliran/features/auth/domain/usecases/logout.dart';
import 'package:giliran/features/auth/domain/usecases/request_email_otp.dart';
import 'package:giliran/features/auth/domain/usecases/resend_email_otp.dart';
import 'package:giliran/features/auth/domain/usecases/set_biometric_enabled.dart';
import 'package:giliran/features/auth/domain/usecases/set_pin.dart';
import 'package:giliran/features/auth/domain/usecases/should_offer_biometric.dart';
import 'package:giliran/features/auth/domain/usecases/verify_email_otp.dart';
import 'package:giliran/features/auth/domain/usecases/verify_pin.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

/// Records each call by name and answers with the configured results.
class _FakeAuthRepository() implements AuthRepository {
  final calls = <String>[];

  Either<Failure, EmailOtpChallenge> challengeResult = const Right(
    EmailOtpChallenge(id: 'otp-1'),
  );
  Either<Failure, EmailOtpResult> verifyResult = const Right(
    EmailOtpResult(purpose: OtpPurpose.signIn),
  );
  Either<Failure, Unit> unitResult = const Right(unit);
  Either<Failure, Unit> logoutResult = const Right(unit);
  Either<Failure, Unit> clearSessionResult = const Right(unit);
  Either<Failure, Unit> savePendingResult = const Right(unit);
  Either<Failure, Unit> saveBiometricEnabledResult = const Right(unit);
  Either<Failure, bool> hasSessionResult = const Right(true);
  Either<Failure, ProfileData?> userResult = const Right(null);
  Either<Failure, PendingOtp?> pendingResult = const Right(null);
  Either<Failure, bool> biometricEnabledResult = const Right(false);
  Either<Failure, bool> biometricPromptedResult = const Right(false);

  PendingOtp? savedPending;
  bool? savedBiometricEnabled;
  bool? savedBiometricPrompted;
  Object? lastArgs;

  Future<T> _record<T>(String name, T value, [Object? args]) async {
    calls.add(name);
    lastArgs = args;
    return value;
  }

  @override
  Future<Either<Failure, EmailOtpChallenge>> requestEmailOtp({
    required OtpPurpose purpose,
    required String email,
    String? pin,
  }) => _record('requestEmailOtp', challengeResult, (purpose, email, pin));

  @override
  Future<Either<Failure, EmailOtpChallenge>> resendEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
  }) => _record('resendEmailOtp', challengeResult, (otpId, purpose));

  @override
  Future<Either<Failure, EmailOtpResult>> verifyEmailOtp(
    String otpId, {
    required OtpPurpose purpose,
    required String code,
    String? pin,
    String? newPin,
    String? newPinConfirmation,
  }) => _record('verifyEmailOtp', verifyResult, (otpId, purpose, code, pin));

  @override
  Future<Either<Failure, Unit>> setPin({
    required String pin,
    required String pinConfirmation,
  }) => _record('setPin', unitResult, (pin, pinConfirmation));

  @override
  Future<Either<Failure, Unit>> changePin({
    required String currentPin,
    required String newPin,
    required String newPinConfirmation,
  }) => _record(
    'changePin',
    unitResult,
    (currentPin, newPin, newPinConfirmation),
  );

  @override
  Future<Either<Failure, Unit>> verifyPin(String pin) => _record('verifyPin', unitResult, pin);

  @override
  Future<Either<Failure, Unit>> logout() => _record('logout', logoutResult);

  @override
  Future<Either<Failure, Unit>> clearSession() => _record('clearSession', clearSessionResult);

  @override
  Future<Either<Failure, bool>> hasSession() => _record('hasSession', hasSessionResult);

  @override
  Future<Either<Failure, ProfileData?>> readCurrentUser() => _record('readCurrentUser', userResult);

  @override
  Future<Either<Failure, Unit>> saveCurrentUser(ProfileData user) => _record('saveCurrentUser', unitResult, user);

  @override
  Future<Either<Failure, PendingOtp?>> readPendingOtp() => _record('readPendingOtp', pendingResult);

  @override
  Future<Either<Failure, Unit>> savePendingOtp(PendingOtp pending) {
    savedPending = pending;
    return _record('savePendingOtp', savePendingResult, pending);
  }

  @override
  Future<Either<Failure, Unit>> clearPendingOtp() => _record('clearPendingOtp', unitResult);

  @override
  Future<Either<Failure, bool>> readBiometricEnabled() => _record('readBiometricEnabled', biometricEnabledResult);

  @override
  Future<Either<Failure, Unit>> saveBiometricEnabled(bool enabled) {
    savedBiometricEnabled = enabled;
    return _record('saveBiometricEnabled', saveBiometricEnabledResult);
  }

  @override
  Future<Either<Failure, bool>> readBiometricPrompted() => _record('readBiometricPrompted', biometricPromptedResult);

  @override
  Future<Either<Failure, Unit>> saveBiometricPrompted(bool prompted) {
    savedBiometricPrompted = prompted;
    return _record('saveBiometricPrompted', unitResult);
  }
}

void main() {
  late _FakeAuthRepository repository;

  setUp(() => repository = _FakeAuthRepository());

  group('RequestEmailOtp', () {
    const params = (
      purpose: OtpPurpose.signIn,
      email: 'ana@example.com',
      pin: null,
    );

    test('saves the sent code as the pending code', () async {
      // Arrange
      final useCase = RequestEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(
        result,
        const Right<Failure, EmailOtpChallenge>(
          EmailOtpChallenge(id: 'otp-1'),
        ),
      );
      expect(
        repository.savedPending,
        const PendingOtp(
          email: 'ana@example.com',
          challenge: EmailOtpChallenge(id: 'otp-1'),
        ),
      );
    });

    test('still succeeds when saving the pending code fails', () async {
      // Arrange
      repository.savePendingResult = const Left(Failure.cache());
      final useCase = RequestEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), isTrue);
    });

    test('returns the failure and saves nothing when the request fails', () async {
      // Arrange
      repository.challengeResult = const Left(Failure.network());
      final useCase = RequestEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, isNot(contains('savePendingOtp')));
    });
  });

  group('ResendEmailOtp', () {
    const params = (otpId: 'otp-1', purpose: OtpPurpose.signIn);
    const resent = EmailOtpChallenge(id: 'otp-1', attemptsRemaining: 4);

    test('refreshes the pending code with the same id', () async {
      // Arrange
      repository
        ..challengeResult = const Right(resent)
        ..pendingResult = const Right(
          PendingOtp(
            email: 'ana@example.com',
            challenge: EmailOtpChallenge(id: 'otp-1'),
          ),
        );
      final useCase = ResendEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result, const Right<Failure, EmailOtpChallenge>(resent));
      expect(
        repository.savedPending,
        const PendingOtp(email: 'ana@example.com', challenge: resent),
      );
    });

    test('leaves a pending code for another request alone', () async {
      // Arrange
      repository.pendingResult = const Right(
        PendingOtp(challenge: EmailOtpChallenge(id: 'otp-other')),
      );
      final useCase = ResendEmailOtp(repository);

      // Act
      await useCase(params);

      // Assert
      expect(repository.calls, isNot(contains('savePendingOtp')));
    });

    test('still succeeds when reading the pending code fails', () async {
      // Arrange
      repository.pendingResult = const Left(Failure.cache());
      final useCase = ResendEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, isNot(contains('savePendingOtp')));
    });

    test('returns the failure when the resend fails', () async {
      // Arrange
      repository.challengeResult = const Left(Failure.network());
      final useCase = ResendEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, ['resendEmailOtp']);
    });
  });

  group('VerifyEmailOtp', () {
    const params = (
      otpId: 'otp-1',
      purpose: OtpPurpose.signIn,
      code: '123456',
      pin: null,
      newPin: null,
      newPinConfirmation: null,
    );

    test('clears the pending code after a verify', () async {
      // Arrange
      final useCase = VerifyEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, ['verifyEmailOtp', 'clearPendingOtp']);
    });

    test('keeps the pending code when the verify fails', () async {
      // Arrange
      repository.verifyResult = const Left(Failure.network());
      final useCase = VerifyEmailOtp(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, ['verifyEmailOtp']);
    });
  });

  group('GetPendingOtp', () {
    final now = DateTime.utc(2026, 11, 2, 10);

    PendingOtp pendingExpiringAt(DateTime expiresAt) => PendingOtp(
      email: 'ana@example.com',
      challenge: EmailOtpChallenge(id: 'otp-1', expiresAt: expiresAt),
    );

    test('returns a code that has not expired', () async {
      // Arrange
      final pending = pendingExpiringAt(now.add(const Duration(minutes: 5)));
      repository.pendingResult = Right(pending);
      final useCase = GetPendingOtp(repository, now: () => now);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, Right<Failure, PendingOtp?>(pending));
      expect(repository.calls, ['readPendingOtp']);
    });

    test('clears an expired code and returns null', () async {
      // Arrange
      repository.pendingResult = Right(pendingExpiringAt(now));
      final useCase = GetPendingOtp(repository, now: () => now);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, PendingOtp?>(null));
      expect(repository.calls, ['readPendingOtp', 'clearPendingOtp']);
    });

    test('returns null when nothing is pending', () async {
      // Arrange
      final useCase = GetPendingOtp(repository, now: () => now);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, PendingOtp?>(null));
    });
  });

  group('Logout', () {
    test('revokes the session, then clears the device', () async {
      // Arrange
      final useCase = Logout(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, Unit>(unit));
      expect(repository.calls, ['logout', 'clearSession']);
    });

    test('still clears the device when the server call fails', () async {
      // Arrange
      repository.logoutResult = const Left(Failure.network());
      final useCase = Logout(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, ['logout', 'clearSession']);
    });

    test('returns the failure when clearing the device fails', () async {
      // Arrange
      repository.clearSessionResult = const Left(Failure.cache());
      final useCase = Logout(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });

  group('ShouldOfferBiometric', () {
    for (final (enabled, prompted, expected) in [
      (false, false, true),
      (false, true, false),
      (true, false, false),
      (true, true, false),
    ]) {
      test('is $expected when enabled=$enabled, prompted=$prompted', () async {
        // Arrange
        repository
          ..biometricEnabledResult = Right(enabled)
          ..biometricPromptedResult = Right(prompted);
        final useCase = ShouldOfferBiometric(repository);

        // Act
        final result = await useCase(const NoParams());

        // Assert
        expect(result, Right<Failure, bool>(expected));
      });
    }

    test('returns the failure when reading fails', () async {
      // Arrange
      repository.biometricEnabledResult = const Left(Failure.cache());
      final useCase = ShouldOfferBiometric(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });

  group('SetBiometricEnabled', () {
    test('saves the choice and marks the opt-in as offered', () async {
      // Arrange
      final useCase = SetBiometricEnabled(repository);

      // Act
      final result = await useCase(true);

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.savedBiometricEnabled, isTrue);
      expect(repository.savedBiometricPrompted, isTrue);
    });

    test('does not mark as offered when saving the choice fails', () async {
      // Arrange
      repository.saveBiometricEnabledResult = const Left(Failure.cache());
      final useCase = SetBiometricEnabled(repository);

      // Act
      final result = await useCase(false);

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
      expect(repository.savedBiometricPrompted, isNull);
    });
  });

  group('pass-through usecases', () {
    test('SetPin sends the PIN and confirmation', () async {
      // Arrange
      final useCase = SetPin(repository);

      // Act
      await useCase((pin: '123456', pinConfirmation: '123456'));

      // Assert
      expect(repository.calls, ['setPin']);
      expect(repository.lastArgs, ('123456', '123456'));
    });

    test('ChangePin sends the current and new PIN', () async {
      // Arrange
      final useCase = ChangePin(repository);

      // Act
      await useCase((
        currentPin: '111111',
        newPin: '222222',
        newPinConfirmation: '222222',
      ));

      // Assert
      expect(repository.lastArgs, ('111111', '222222', '222222'));
    });

    test('VerifyPin returns the repository failure', () async {
      // Arrange
      repository.unitResult = const Left(Failure.network());
      final useCase = VerifyPin(repository);

      // Act
      final result = await useCase('123456');

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.lastArgs, '123456');
    });

    test('HasSession returns the stored session flag', () async {
      // Arrange
      final useCase = HasSession(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, bool>(true));
    });

    test('GetCurrentUser returns the cached user', () async {
      // Arrange
      final useCase = GetCurrentUser(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, ProfileData?>(null));
      expect(repository.calls, ['readCurrentUser']);
    });

    test('GetBiometricEnabled returns the stored flag', () async {
      // Arrange
      repository.biometricEnabledResult = const Right(true);
      final useCase = GetBiometricEnabled(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, bool>(true));
    });
  });
}
