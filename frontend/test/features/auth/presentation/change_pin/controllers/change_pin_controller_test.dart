import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/features/auth/presentation/change_pin/controllers/change_pin_controller.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = authTestContainer(repository);
    container.listen(changePinControllerProvider, (_, _) {});
  });

  ChangePinController controller() => container.read(changePinControllerProvider.notifier);

  ChangePinState state() => container.read(changePinControllerProvider);

  Future<void> enterAll() async {
    await controller().enter('111111');
    await controller().enter('246802');
    await controller().enter('246802');
  }

  test('steps through current, new and repeat, then changes the PIN', () async {
    // Arrange
    // (a fresh pad)

    // Act
    await enterAll();

    // Assert
    expect(state().done, isTrue);
    expect(repository.lastArgs, ('111111', '246802', '246802'));
  });

  test('a wrong current PIN goes back to the first step', () async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinInvalid, status: 401),
    );

    // Act
    await enterAll();

    // Assert
    expect(state().step, ChangePinStep.current);
    expect(state().currentPin, isNull);
  });

  test('a rejected new PIN goes back to the new PIN step', () async {
    // Arrange
    repository.unitResult = const Left(Failure.validation());

    // Act
    await enterAll();

    // Assert
    expect(state().step, ChangePinStep.newPin);
    expect(state().currentPin, '111111');
    expect(state().failure, isA<ValidationFailure>());
  });

  test('a locked current PIN sets the lock countdown from Retry-After', () async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinLocked,
        status: 423,
        retryAfter: Duration(minutes: 15),
      ),
    );
    final before = DateTime.now();

    // Act
    await enterAll();

    // Assert
    expect(state().step, ChangePinStep.current);
    expect(
      state().lockedUntil?.isAfter(before.add(const Duration(minutes: 14))),
      isTrue,
    );
  });

  test('ignores entries while locked, until the countdown finishes', () async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(
        code: ApiErrorCode.pinLocked,
        status: 423,
        retryAfter: Duration(minutes: 15),
      ),
    );
    await enterAll();

    // Act
    await controller().enter('111111');
    final whileLocked = state().step;
    controller().lockFinished();
    await controller().enter('111111');

    // Assert
    expect(whileLocked, ChangePinStep.current);
    expect(state().step, ChangePinStep.newPin);
    expect(state().lockedUntil, isNull);
  });

  test('back steps from repeat to new to current, then lets the page close', () async {
    // Arrange
    await controller().enter('111111');
    await controller().enter('246802');

    // Act
    final fromConfirm = controller().back();
    final afterConfirm = state();
    final fromNew = controller().back();
    final afterNew = state().step;
    final fromCurrent = controller().back();

    // Assert
    expect(fromConfirm, isTrue);
    expect(afterConfirm.step, ChangePinStep.newPin);
    expect(afterConfirm.currentPin, '111111');
    expect(afterConfirm.newPin, isNull);
    expect(fromNew, isTrue);
    expect(afterNew, ChangePinStep.current);
    expect(fromCurrent, isFalse);
  });

  test('clearFailure drops the shown error', () async {
    // Arrange
    repository.unitResult = const Left(
      Failure.badRequest(code: ApiErrorCode.pinInvalid, status: 401),
    );
    await enterAll();

    // Act
    controller().clearFailure();

    // Assert
    expect(state().failure, isNull);
  });
}
