import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/core/utils/enums/biometric_kind.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_challenge.dart';
import 'package:giliran/features/auth/domain/entities/email_otp_result.dart';
import 'package:giliran/features/auth/domain/repositories/auth_repository.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

/// Records each call by name and answers with the configured results. Once
/// something is saved (user, biometric flags), reads return the saved value.
class FakeAuthRepository() implements AuthRepository {
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
  ProfileData? savedUser;
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
  Future<Either<Failure, ProfileData?>> readCurrentUser() => _record(
    'readCurrentUser',
    savedUser == null ? userResult : Right(savedUser),
  );

  @override
  Future<Either<Failure, Unit>> saveCurrentUser(ProfileData user) {
    savedUser = user;
    return _record('saveCurrentUser', unitResult, user);
  }

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
  Future<Either<Failure, bool>> readBiometricEnabled() => _record(
    'readBiometricEnabled',
    savedBiometricEnabled == null ? biometricEnabledResult : Right(savedBiometricEnabled!),
  );

  @override
  Future<Either<Failure, Unit>> saveBiometricEnabled(bool enabled) {
    savedBiometricEnabled = enabled;
    return _record('saveBiometricEnabled', saveBiometricEnabledResult);
  }

  @override
  Future<Either<Failure, bool>> readBiometricPrompted() => _record(
    'readBiometricPrompted',
    savedBiometricPrompted == null ? biometricPromptedResult : Right(savedBiometricPrompted!),
  );

  @override
  Future<Either<Failure, Unit>> saveBiometricPrompted(bool prompted) {
    savedBiometricPrompted = prompted;
    return _record('saveBiometricPrompted', unitResult);
  }
}

/// A [BiometricService] that answers with [kind] and [authenticated] instead
/// of showing the system prompt.
class FakeBiometricService() implements BiometricService {
  BiometricKind? kind = BiometricKind.fingerprint;
  bool authenticated = true;
  int authenticateCalls = 0;

  @override
  Future<BiometricKind?> availableKind() async => kind;

  @override
  Future<bool> authenticate(String reason) async {
    authenticateCalls++;
    return authenticated;
  }
}

/// A container whose auth providers run on [repository] and [biometric],
/// disposed after the test.
ProviderContainer authTestContainer(
  FakeAuthRepository repository, {
  BiometricService? biometric,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      biometricServiceProvider.overrideWithValue(
        biometric ?? FakeBiometricService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
