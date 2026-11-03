import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/usecase/usecase.dart';
import 'package:giliran/core/utils/enums/biometric_kind.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/domain/entities/biometric_status.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/domain/usecases/change_pin_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/get_biometric_enabled_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/get_biometric_status_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/get_pending_otp_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/has_session_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/logout_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/request_email_otp_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/resend_email_otp_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/resolve_auth_status_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/set_biometric_enabled_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/set_pin_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/should_lock_on_resume_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/should_offer_biometric_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/unlock_with_biometric_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/validate_new_email_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/verify_email_otp_usecase.dart';
import 'package:giliran/features/auth/domain/usecases/verify_pin_usecase.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  group('RequestEmailOtpUseCase', () {
    const params = (
      purpose: OtpPurpose.signIn,
      email: 'ana@example.com',
      pin: null,
    );

    test('saves the sent code as the pending code', () async {
      // Arrange
      final useCase = RequestEmailOtpUseCase(repository);

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
      final useCase = RequestEmailOtpUseCase(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), isTrue);
    });

    test('returns the failure and saves nothing when the request fails', () async {
      // Arrange
      repository.challengeResult = const Left(Failure.network());
      final useCase = RequestEmailOtpUseCase(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, isNot(contains('savePendingOtp')));
    });
  });

  group('ResendEmailOtpUseCase', () {
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
      final useCase = ResendEmailOtpUseCase(repository);

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
      final useCase = ResendEmailOtpUseCase(repository);

      // Act
      await useCase(params);

      // Assert
      expect(repository.calls, isNot(contains('savePendingOtp')));
    });

    test('still succeeds when reading the pending code fails', () async {
      // Arrange
      repository.pendingResult = const Left(Failure.cache());
      final useCase = ResendEmailOtpUseCase(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, isNot(contains('savePendingOtp')));
    });

    test('returns the failure when the resend fails', () async {
      // Arrange
      repository.challengeResult = const Left(Failure.network());
      final useCase = ResendEmailOtpUseCase(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, ['resendEmailOtp']);
    });
  });

  group('VerifyEmailOtpUseCase', () {
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
      final useCase = VerifyEmailOtpUseCase(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, ['verifyEmailOtp', 'clearPendingOtp']);
    });

    test('keeps the pending code when the verify fails', () async {
      // Arrange
      repository.verifyResult = const Left(Failure.network());
      final useCase = VerifyEmailOtpUseCase(repository);

      // Act
      final result = await useCase(params);

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, ['verifyEmailOtp']);
    });
  });

  group('GetPendingOtpUseCase', () {
    final now = DateTime.utc(2026, 11, 2, 10);

    PendingOtp pendingExpiringAt(DateTime expiresAt) => PendingOtp(
      email: 'ana@example.com',
      challenge: EmailOtpChallenge(id: 'otp-1', expiresAt: expiresAt),
    );

    test('returns a code that has not expired', () async {
      // Arrange
      final pending = pendingExpiringAt(now.add(const Duration(minutes: 5)));
      repository.pendingResult = Right(pending);
      final useCase = GetPendingOtpUseCase(repository, now: () => now);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, Right<Failure, PendingOtp?>(pending));
      expect(repository.calls, ['readPendingOtp']);
    });

    test('clears an expired code and returns null', () async {
      // Arrange
      repository.pendingResult = Right(pendingExpiringAt(now));
      final useCase = GetPendingOtpUseCase(repository, now: () => now);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, PendingOtp?>(null));
      expect(repository.calls, ['readPendingOtp', 'clearPendingOtp']);
    });

    test('returns null when nothing is pending', () async {
      // Arrange
      final useCase = GetPendingOtpUseCase(repository, now: () => now);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, PendingOtp?>(null));
    });
  });

  group('LogoutUseCase', () {
    test('revokes the session, then clears the device', () async {
      // Arrange
      final useCase = LogoutUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, Unit>(unit));
      expect(repository.calls, ['logout', 'clearSession']);
    });

    test('still clears the device when the server call fails', () async {
      // Arrange
      repository.logoutResult = const Left(Failure.network());
      final useCase = LogoutUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.calls, ['logout', 'clearSession']);
    });

    test('returns the failure when clearing the device fails', () async {
      // Arrange
      repository.clearSessionResult = const Left(Failure.cache());
      final useCase = LogoutUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });

  group('ShouldOfferBiometricUseCase', () {
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
        final useCase = ShouldOfferBiometricUseCase(repository);

        // Act
        final result = await useCase(const NoParams());

        // Assert
        expect(result, Right<Failure, bool>(expected));
      });
    }

    test('returns the failure when reading fails', () async {
      // Arrange
      repository.biometricEnabledResult = const Left(Failure.cache());
      final useCase = ShouldOfferBiometricUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });

  group('SetBiometricEnabledUseCase', () {
    test('saves the choice and marks the opt-in as offered', () async {
      // Arrange
      final useCase = SetBiometricEnabledUseCase(repository);

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
      final useCase = SetBiometricEnabledUseCase(repository);

      // Act
      final result = await useCase(false);

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
      expect(repository.savedBiometricPrompted, isNull);
    });
  });

  group('pass-through usecases', () {
    test('SetPinUseCase sends the PIN and saves nothing without a cached user', () async {
      // Arrange
      final useCase = SetPinUseCase(repository);

      // Act
      await useCase((pin: '123456', pinConfirmation: '123456'));

      // Assert
      expect(repository.calls.first, 'setPin');
      expect(repository.calls, isNot(contains('saveCurrentUser')));
    });

    test('ChangePinUseCase sends the current and new PIN', () async {
      // Arrange
      final useCase = ChangePinUseCase(repository);

      // Act
      await useCase((
        currentPin: '111111',
        newPin: '222222',
        newPinConfirmation: '222222',
      ));

      // Assert
      expect(repository.lastArgs, ('111111', '222222', '222222'));
    });

    test('VerifyPinUseCase returns the repository failure', () async {
      // Arrange
      repository.unitResult = const Left(Failure.network());
      final useCase = VerifyPinUseCase(repository);

      // Act
      final result = await useCase('123456');

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.lastArgs, '123456');
    });

    test('HasSessionUseCase returns the stored session flag', () async {
      // Arrange
      final useCase = HasSessionUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, bool>(true));
    });

    test('GetCurrentUserUseCase returns the cached user', () async {
      // Arrange
      final useCase = GetCurrentUserUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, ProfileData?>(null));
      expect(repository.calls, ['readCurrentUser']);
    });

    test('GetBiometricEnabledUseCase returns the stored flag', () async {
      // Arrange
      repository.biometricEnabledResult = const Right(true);
      final useCase = GetBiometricEnabledUseCase(repository);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result, const Right<Failure, bool>(true));
    });
  });

  group('SetPinUseCase', () {
    test('marks the cached user as having a PIN', () async {
      // Arrange
      repository.userResult = Right(ProfileData(name: 'Ana', pinSet: false));
      final useCase = SetPinUseCase(repository);

      // Act
      final result = await useCase((pin: '135790', pinConfirmation: '135790'));

      // Assert
      expect(result.isRight(), isTrue);
      expect(repository.savedUser?.pinSet, isTrue);
      expect(repository.lastArgs, isA<ProfileData>());
    });

    test('leaves the cached user alone when the API rejects the PIN', () async {
      // Arrange
      repository
        ..unitResult = const Left(Failure.network())
        ..userResult = Right(ProfileData(name: 'Ana', pinSet: false));
      final useCase = SetPinUseCase(repository);

      // Act
      final result = await useCase((pin: '123456', pinConfirmation: '123456'));

      // Assert
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(repository.calls, ['setPin']);
    });
  });

  group('VerifyEmailOtpUseCase change_email', () {
    test('caches the updated user', () async {
      // Arrange
      final user = ProfileData(email: 'baru@example.com');
      repository.verifyResult = Right(
        EmailOtpResult(purpose: OtpPurpose.changeEmail, user: user),
      );
      final useCase = VerifyEmailOtpUseCase(repository);

      // Act
      await useCase((
        otpId: 'otp-1',
        purpose: OtpPurpose.changeEmail,
        code: '123456',
        pin: null,
        newPin: null,
        newPinConfirmation: null,
      ));

      // Assert
      expect(repository.savedUser, user);
    });
  });

  group('ShouldLockOnResumeUseCase', () {
    final hiddenAt = DateTime(2026, 11, 2, 9);

    test('keeps the session open under five minutes away', () async {
      // Arrange
      const useCase = ShouldLockOnResumeUseCase();

      // Act
      final result = await useCase((
        hiddenAt: hiddenAt,
        now: hiddenAt.add(const Duration(minutes: 4, seconds: 59)),
      ));

      // Assert
      expect(result, const Right<Failure, bool>(false));
    });

    test('locks from five minutes away', () async {
      // Arrange
      const useCase = ShouldLockOnResumeUseCase();

      // Act
      final result = await useCase((
        hiddenAt: hiddenAt,
        now: hiddenAt.add(ShouldLockOnResumeUseCase.autoLockAfter),
      ));

      // Assert
      expect(result, const Right<Failure, bool>(true));
    });
  });

  group('ValidateNewEmailUseCase', () {
    setUp(() => repository.userResult = Right(ProfileData(email: 'ana@example.com')));

    test('returns a different address trimmed and lowercased', () async {
      // Arrange
      final useCase = ValidateNewEmailUseCase(repository);

      // Act
      final result = await useCase('  Baru@Example.com ');

      // Assert
      expect(result, const Right<Failure, String>('baru@example.com'));
    });

    test('rejects the current address, ignoring case and spaces', () async {
      // Arrange
      final useCase = ValidateNewEmailUseCase(repository);

      // Act
      final result = await useCase(' ANA@example.com');

      // Assert
      final failure = result.getLeft().toNullable();
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors.single.code,
        ValidateNewEmailUseCase.sameEmailCode,
      );
    });

    test('passes the cache failure through', () async {
      // Arrange
      repository.userResult = const Left(Failure.cache());
      final useCase = ValidateNewEmailUseCase(repository);

      // Act
      final result = await useCase('baru@example.com');

      // Assert
      expect(result, const Left<Failure, String>(Failure.cache()));
    });
  });

  group('ResolveAuthStatusUseCase', () {
    late ResolveAuthStatusUseCase useCase;

    setUp(() => useCase = ResolveAuthStatusUseCase(repository, GetPendingOtpUseCase(repository)));

    test('signs out with no session and no open code', () async {
      // Arrange
      repository.hasSessionResult = const Right(false);

      // Act
      final result = await useCase((unlocked: false));

      // Assert
      expect(result, const Right<Failure, AuthStatus>(AuthStatus.signedOut()));
    });

    test('resumes an open code request without a session', () async {
      // Arrange
      final pending = PendingOtp(
        email: 'ana@example.com',
        challenge: EmailOtpChallenge(
          id: 'otp-1',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      repository
        ..hasSessionResult = const Right(false)
        ..pendingResult = Right(pending);

      // Act
      final result = await useCase((unlocked: false));

      // Assert
      expect(
        result,
        Right<Failure, AuthStatus>(AuthStatus.otpPending(pending: pending)),
      );
    });

    test('asks for a name when the cached user has none', () async {
      // Arrange
      final user = ProfileData(name: '  ', pinSet: true);
      repository.userResult = Right(user);

      // Act
      final result = await useCase((unlocked: true));

      // Assert
      expect(result, Right<Failure, AuthStatus>(AuthStatus.needsName(user: user)));
    });

    test('asks for a PIN when the account has none', () async {
      // Arrange
      final user = ProfileData(name: 'Ana', pinSet: false);
      repository.userResult = Right(user);

      // Act
      final result = await useCase((unlocked: false));

      // Assert
      expect(result, Right<Failure, AuthStatus>(AuthStatus.needsPin(user: user)));
    });

    test('locks a complete session unless the PIN was just proved', () async {
      // Arrange
      final user = ProfileData(name: 'Ana', pinSet: true);
      repository.userResult = Right(user);

      // Act
      final onLaunch = await useCase((unlocked: false));
      final afterPin = await useCase((unlocked: true));

      // Assert
      expect(onLaunch, Right<Failure, AuthStatus>(AuthStatus.locked(user: user)));
      expect(afterPin, Right<Failure, AuthStatus>(AuthStatus.unlocked(user: user)));
    });

    test('returns the failure when the session cannot be read', () async {
      // Arrange
      repository.hasSessionResult = const Left(Failure.cache());

      // Act
      final result = await useCase((unlocked: false));

      // Assert
      expect(result.getLeft().toNullable(), isA<CacheFailure>());
    });
  });

  group('GetBiometricStatusUseCase', () {
    late FakeBiometricService biometric;

    setUp(() => biometric = FakeBiometricService());

    test('offers the opt-in when enrolled, off and never asked', () async {
      // Arrange
      final useCase = GetBiometricStatusUseCase(repository, biometric);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(
        result,
        const Right<Failure, BiometricStatus>(
          BiometricStatus(
            kind: BiometricKind.fingerprint,
            enabled: false,
            shouldOffer: true,
          ),
        ),
      );
    });

    test('does not offer without an enrolled biometric', () async {
      // Arrange
      biometric.kind = null;
      final useCase = GetBiometricStatusUseCase(repository, biometric);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.toNullable()?.shouldOffer, isFalse);
    });

    test('does not offer once it was asked', () async {
      // Arrange
      repository.biometricPromptedResult = const Right(true);
      final useCase = GetBiometricStatusUseCase(repository, biometric);

      // Act
      final result = await useCase(const NoParams());

      // Assert
      expect(result.toNullable()?.shouldOffer, isFalse);
    });
  });

  group('UnlockWithBiometricUseCase', () {
    late FakeBiometricService biometric;

    setUp(() => biometric = FakeBiometricService());

    test('prompts when biometric unlock is on', () async {
      // Arrange
      repository.biometricEnabledResult = const Right(true);
      final useCase = UnlockWithBiometricUseCase(repository, biometric);

      // Act
      final result = await useCase('Buka Giliran');

      // Assert
      expect(result, const Right<Failure, bool>(true));
      expect(biometric.authenticateCalls, 1);
    });

    test('does not prompt when it is off', () async {
      // Arrange
      final useCase = UnlockWithBiometricUseCase(repository, biometric);

      // Act
      final result = await useCase('Buka Giliran');

      // Assert
      expect(result, const Right<Failure, bool>(false));
      expect(biometric.authenticateCalls, 0);
    });

    test('does not prompt when nothing is enrolled', () async {
      // Arrange
      repository.biometricEnabledResult = const Right(true);
      biometric.kind = null;
      final useCase = UnlockWithBiometricUseCase(repository, biometric);

      // Act
      final result = await useCase('Buka Giliran');

      // Assert
      expect(result, const Right<Failure, bool>(false));
      expect(biometric.authenticateCalls, 0);
    });
  });
}
