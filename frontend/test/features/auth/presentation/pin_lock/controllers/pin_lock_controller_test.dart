import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/auth/presentation/pin_lock/controllers/pin_lock_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeBiometricService biometric;
  late ProviderContainer container;

  setUp(() async {
    repository = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Ana', pinSet: true));
    biometric = FakeBiometricService();
    container = authTestContainer(repository, biometric: biometric);
    container.listen(pinLockControllerProvider, (_, _) {});
    await container.read(authSessionControllerProvider.future);
  });

  PinLockController controller() => container.read(pinLockControllerProvider.notifier);

  AuthStatus? session() => container.read(authSessionControllerProvider).value;

  test('a correct PIN unlocks the session', () async {
    // Arrange
    // (a locked session from setUp)

    // Act
    await controller().verify('135790');

    // Assert
    expect(session(), isA<AuthUnlocked>());
  });

  test('a wrong PIN keeps the lock and shows the attempts left', () async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinInvalid,
        status: 401,
        extensions: {'attempts_remaining': 2},
      ),
    );

    // Act
    await controller().verify('000000');

    // Assert
    expect(container.read(pinLockControllerProvider).attemptsRemaining, 2);
    expect(session(), isA<AuthLocked>());
  });

  test('pin_locked sets when entry opens again', () async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinLocked,
        status: 423,
        retryAfter: Duration(minutes: 15),
      ),
    );

    // Act
    await controller().verify('000000');

    // Assert
    final lockedUntil = container.read(pinLockControllerProvider).lockedUntil;
    expect(
      lockedUntil?.isAfter(DateTime.now().add(const Duration(minutes: 14))),
      isTrue,
    );
  });

  test('a passed biometric prompt unlocks when it is on', () async {
    // Arrange
    repository.biometricEnabledResult = const Right(true);

    // Act
    await controller().unlockWithBiometric('Buka Giliran');

    // Assert
    expect(session(), isA<AuthUnlocked>());
  });

  test('a cancelled biometric prompt keeps the lock', () async {
    // Arrange
    repository.biometricEnabledResult = const Right(true);
    biometric.authenticated = false;

    // Act
    await controller().unlockWithBiometric('Buka Giliran');

    // Assert
    expect(session(), isA<AuthLocked>());
  });
}
