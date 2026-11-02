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
}
