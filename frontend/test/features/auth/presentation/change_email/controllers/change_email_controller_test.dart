import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/otp_purpose.dart';
import 'package:giliran/features/auth/presentation/change_email/controllers/change_email_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository()..userResult = Right(ProfileData(email: 'ana@example.com'));
    container = authTestContainer(repository);
    container.listen(changeEmailControllerProvider, (_, _) {});
  });

  ChangeEmailController controller() => container.read(changeEmailControllerProvider.notifier);

  ChangeEmailState state() => container.read(changeEmailControllerProvider);

  Future<void> toPinStep() => controller().submitEmail('Baru@Example.com');

  group('submitEmail', () {
    test('moves on to the PIN with the address normalized', () async {
      // Arrange
      // (the account email is ana@example.com)

      // Act
      await toPinStep();

      // Assert
      expect(state().step, ChangeEmailStep.pin);
      expect(state().newEmail, 'baru@example.com');
      expect(state().failure, isNull);
    });

    test('stays on step 1 for the current address', () async {
      // Arrange
      // (the account email is ana@example.com)

      // Act
      await controller().submitEmail('ana@example.com');

      // Assert
      expect(state().step, ChangeEmailStep.email);
      expect(state().failure, isA<ValidationFailure>());
    });
  });

  group('submitPin', () {
    test('sends a change_email code with the PIN and opens the code step', () async {
      // Arrange
      await toPinStep();

      // Act
      await controller().submitPin('246802');

      // Assert
      expect(state().step, ChangeEmailStep.code);
      expect(repository.calls, contains('requestEmailOtp'));
      expect(repository.savedPending?.email, 'baru@example.com');
      expect(repository.savedPending?.challenge?.id, 'otp-1');
    });

    test('sends the change_email purpose, the new address and the PIN', () async {
      // Arrange
      await toPinStep();

      // Act
      await controller().submitPin('246802');

      // Assert
      expect(
        repository.requestArgs,
        (OtpPurpose.changeEmail, 'baru@example.com', '246802'),
      );
    });

    test('a wrong PIN stays on the PIN step with the failure', () async {
      // Arrange
      await toPinStep();
      repository.challengeResult = const Left(
        Failure.badRequest(code: ApiErrorCode.pinInvalid, status: 401),
      );

      // Act
      await controller().submitPin('000000');

      // Assert
      expect(state().step, ChangeEmailStep.pin);
      expect(state().failure?.apiCode, ApiErrorCode.pinInvalid);
      expect(state().lockedUntil, isNull);
    });

    test('a locked PIN sets the countdown and ignores entries until it ends', () async {
      // Arrange
      await toPinStep();
      repository.challengeResult = const Left(
        Failure.badRequest(
          code: ApiErrorCode.pinLocked,
          status: 423,
          retryAfter: Duration(minutes: 15),
        ),
      );
      await controller().submitPin('000000');
      repository.calls.clear();

      // Act
      await controller().submitPin('246802');
      final callsWhileLocked = List.of(repository.calls);
      controller().lockFinished();

      // Assert
      expect(callsWhileLocked, isEmpty);
      expect(state().lockedUntil, isNull);
      expect(state().step, ChangeEmailStep.pin);
    });

    test('a taken address goes back to step 1 with the conflict', () async {
      // Arrange
      await toPinStep();
      repository.challengeResult = const Left(
        Failure.conflict(code: ApiErrorCode.emailAlreadyRegistered),
      );

      // Act
      await controller().submitPin('246802');

      // Assert
      expect(state().step, ChangeEmailStep.email);
      expect(state().newEmail, 'baru@example.com');
      expect(state().failure, isA<ConflictFailure>());
    });

    test('a network failure stays on the PIN step', () async {
      // Arrange
      await toPinStep();
      repository.challengeResult = const Left(Failure.network());

      // Act
      await controller().submitPin('246802');

      // Assert
      expect(state().step, ChangeEmailStep.pin);
      expect(state().failure, const Failure.network());
    });
  });

  group('back', () {
    test('steps from code to PIN to email, then lets the page close', () async {
      // Arrange
      await toPinStep();
      await controller().submitPin('246802');

      // Act
      final fromCode = controller().back();
      final afterCode = state().step;
      final fromPin = controller().back();
      final afterPin = state();
      final fromEmail = controller().back();

      // Assert
      expect(fromCode, isTrue);
      expect(afterCode, ChangeEmailStep.pin);
      expect(fromPin, isTrue);
      expect(afterPin.step, ChangeEmailStep.email);
      expect(afterPin.newEmail, 'baru@example.com');
      expect(fromEmail, isFalse);
    });
  });

  test('editEmail returns to step 1 keeping the new address', () async {
    // Arrange
    await toPinStep();
    await controller().submitPin('246802');

    // Act
    controller().editEmail();

    // Assert
    expect(state().step, ChangeEmailStep.email);
    expect(state().newEmail, 'baru@example.com');
  });
}
