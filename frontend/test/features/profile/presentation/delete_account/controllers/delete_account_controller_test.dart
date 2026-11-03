import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/presentation/delete_account/controllers/delete_account_controller.dart';

import '../../../../../core/database/fixtures.dart';
import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late ProviderContainer container;

  setUp(() {
    profile = FakeProfileRepository();
    final db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        profileRepositoryProvider.overrideWithValue(profile),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    container.listen(deleteAccountControllerProvider, (_, _) {});
  });

  DeleteAccountController notifier() => container.read(deleteAccountControllerProvider.notifier);

  DeleteAccountState state() => container.read(deleteAccountControllerProvider);

  test('next waits for Saya mengerti', () {
    // Arrange
    final before = state().step;

    // Act
    notifier().next();
    final withoutCheck = state().step;
    notifier()
      ..setUnderstood(true)
      ..next();

    // Assert
    expect(before, DeleteAccountStep.explain);
    expect(withoutCheck, DeleteAccountStep.explain);
    expect(state().step, DeleteAccountStep.pin);
  });

  test('the right PIN finishes the flow', () async {
    // Arrange
    notifier()
      ..setUnderstood(true)
      ..next();

    // Act
    await notifier().enter('123456');

    // Assert
    expect(state().step, DeleteAccountStep.done);
    expect(profile.deletedWithPins, ['123456']);
  });

  test('obligations_outstanding goes back to step 1 and blocks it', () async {
    // Arrange
    profile.deleteAccountResult = const Left(
      Failure.conflict(code: ApiErrorCode.obligationsOutstanding),
    );
    notifier()
      ..setUnderstood(true)
      ..next();

    // Act
    await notifier().enter('123456');
    notifier().next();

    // Assert
    expect(state().step, DeleteAccountStep.explain);
    expect(state().blocked, isTrue);
  });

  test('pin_invalid stays on the PIN step with the failure', () async {
    // Arrange
    profile.deleteAccountResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinInvalid, status: 401, extensions: {'attempts_remaining': 2}),
    );
    notifier()
      ..setUnderstood(true)
      ..next();

    // Act
    await notifier().enter('000000');

    // Assert
    expect(state().step, DeleteAccountStep.pin);
    expect(state().failure?.attemptsRemaining, 2);
  });

  test('pin_locked starts the lock countdown', () async {
    // Arrange
    profile.deleteAccountResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinLocked, status: 423, retryAfter: Duration(minutes: 5)),
    );
    notifier()
      ..setUnderstood(true)
      ..next();

    // Act
    await notifier().enter('000000');

    // Assert
    expect(state().lockedUntil, isNotNull);
  });

  test('back from the PIN step returns to step 1, then closes', () {
    // Arrange
    notifier()
      ..setUnderstood(true)
      ..next();

    // Act
    final steppedBack = notifier().back();
    final closes = !notifier().back();

    // Assert
    expect(steppedBack, isTrue);
    expect(closes, isTrue);
    expect(state().step, DeleteAccountStep.explain);
  });
}
