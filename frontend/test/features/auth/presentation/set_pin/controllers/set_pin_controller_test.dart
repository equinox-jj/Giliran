import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/auth/presentation/set_pin/controllers/set_pin_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Ana', pinSet: false));
    container = authTestContainer(repository);
    container.listen(setPinControllerProvider, (_, _) {});
  });

  SetPinController controller() => container.read(setPinControllerProvider.notifier);

  test('keeps the first entry and asks again', () async {
    // Arrange
    // (a fresh pad)

    // Act
    await controller().enter('135790');

    // Assert
    expect(container.read(setPinControllerProvider).firstPin, '135790');
    expect(repository.calls, isNot(contains('setPin')));
  });

  test('sets the PIN on the second entry and unlocks the session', () async {
    // Arrange
    await controller().enter('135790');

    // Act
    await controller().enter('135790');

    // Assert
    expect(container.read(setPinControllerProvider).done, isTrue);
    expect(repository.lastArgs, isA<ProfileData>());
    expect(
      container.read(authSessionControllerProvider).value,
      isA<AuthUnlocked>(),
    );
  });

  test('starts over when the API rejects the PIN', () async {
    // Arrange
    repository.unitResult = const Left(Failure.validation());
    await controller().enter('123456');

    // Act
    await controller().enter('123456');

    // Assert
    final state = container.read(setPinControllerProvider);
    expect(state.firstPin, isNull);
    expect(state.failure, isA<ValidationFailure>());
  });
}
