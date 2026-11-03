import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';
import 'package:giliran/features/profile/presentation/edit_profile/controllers/edit_profile_controller.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository()..userResult = Right(ProfileData(name: 'Rina', pinSet: true));
    profile = FakeProfileRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    container.listen(editProfileControllerProvider, (_, _) {});
  });

  test('a save refreshes the session with the new name', () async {
    // Arrange
    await container.read(authSessionControllerProvider.future);
    profile.updateResult = Right(ProfileData(name: 'Rina Ayu', pinSet: true));

    // Act
    final saved = await container.read(editProfileControllerProvider.notifier).save(name: 'Rina Ayu');

    // Assert
    final status = container.read(authSessionControllerProvider).value;
    expect(saved, isTrue);
    expect(status, isA<AuthUnlocked>());
    expect((status! as AuthUnlocked).user?.name, 'Rina Ayu');
  });

  test('a rejected save keeps the failure in state', () async {
    // Arrange
    profile.updateResult = const Left(Failure.validation());

    // Act
    final saved = await container.read(editProfileControllerProvider.notifier).save(name: 'R');

    // Assert
    expect(saved, isFalse);
    expect(container.read(editProfileControllerProvider).error, isA<ValidationFailure>());
  });

  test('clearError drops the shown failure', () async {
    // Arrange
    profile.updateResult = const Left(Failure.validation());
    await container.read(editProfileControllerProvider.notifier).save(name: 'R');

    // Act
    container.read(editProfileControllerProvider.notifier).clearError();

    // Assert
    expect(container.read(editProfileControllerProvider).hasError, isFalse);
  });
}
