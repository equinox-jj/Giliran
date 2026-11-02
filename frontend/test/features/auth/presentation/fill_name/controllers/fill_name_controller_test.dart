import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/services/biometric_service.dart';
import 'package:giliran/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/fill_name/controllers/fill_name_controller.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../../helpers/fake_auth_repository.dart';
import '../../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository()..userResult = Right(ProfileData(pinSet: false));
    profile = FakeProfileRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    container.listen(fillNameControllerProvider, (_, _) {});
  });

  test('saves the name and moves the session on to the PIN step', () async {
    // Arrange
    final controller = container.read(fillNameControllerProvider.notifier);

    // Act
    final saved = await controller.submit(name: 'Rina', phone: '+6281234567890');

    // Assert
    expect(saved, isTrue);
    expect(profile.lastUpdate, (name: 'Rina', phone: '+6281234567890'));
    expect(
      container.read(authSessionControllerProvider).value,
      isA<AuthNeedsPin>(),
    );
  });

  test('holds the failure when the server rejects the name', () async {
    // Arrange
    profile.updateResult = const Left(Failure.validation());
    final controller = container.read(fillNameControllerProvider.notifier);

    // Act
    final saved = await controller.submit(name: 'R');

    // Assert
    expect(saved, isFalse);
    expect(
      container.read(fillNameControllerProvider).error,
      isA<ValidationFailure>(),
    );
  });
}
