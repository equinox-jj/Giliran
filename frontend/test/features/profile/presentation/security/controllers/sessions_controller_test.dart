import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/features/profile/data/repository/profile_repository_impl.dart';
import 'package:giliran/features/profile/domain/entity/session.dart';
import 'package:giliran/features/profile/presentation/security/controllers/sessions_controller.dart';

import '../../../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profile;
  late ProviderContainer container;

  const sessions = [
    Session(id: 'me', deviceName: 'Pixel 8', isCurrent: true),
    Session(id: 'tablet', deviceName: 'Galaxy Tab', isCurrent: false),
    Session(id: 'old-phone', deviceName: 'iPhone 11', isCurrent: false),
  ];

  setUp(() {
    profile = FakeProfileRepository()..sessionsResult = const Right(sessions);
    container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(profile)],
    );
    addTearDown(container.dispose);
    container.listen(sessionsControllerProvider, (_, _) {});
  });

  test('loads the sessions', () async {
    // Arrange
    final provider = sessionsControllerProvider;

    // Act
    final loaded = await container.read(provider.future);

    // Assert
    expect(loaded, sessions);
  });

  test('revoke removes that row', () async {
    // Arrange
    await container.read(sessionsControllerProvider.future);

    // Act
    final failure = await container.read(sessionsControllerProvider.notifier).revoke('tablet');

    // Assert
    expect(failure, isNull);
    expect(container.read(sessionsControllerProvider).value?.map((s) => s.id), ['me', 'old-phone']);
  });

  test('a failed revoke keeps the row and returns the failure', () async {
    // Arrange
    await container.read(sessionsControllerProvider.future);
    profile.revokeResults['tablet'] = const Left(Failure.network());

    // Act
    final failure = await container.read(sessionsControllerProvider.notifier).revoke('tablet');

    // Assert
    expect(failure, isA<NetworkFailure>());
    expect(container.read(sessionsControllerProvider).value, sessions);
  });

  test('revokeOthers leaves only this device', () async {
    // Arrange
    await container.read(sessionsControllerProvider.future);

    // Act
    final result = await container.read(sessionsControllerProvider.notifier).revokeOthers();

    // Assert
    expect(result, const Right<Failure, int>(2));
    expect(container.read(sessionsControllerProvider).value?.map((s) => s.id), ['me']);
  });

  test('a failed load surfaces the failure and reload recovers', () async {
    // Arrange
    await container.read(sessionsControllerProvider.future);
    final controller = container.read(sessionsControllerProvider.notifier);
    profile.sessionsResult = const Left(Failure.network());
    await controller.reload();
    final failed = container.read(sessionsControllerProvider);
    profile.sessionsResult = const Right(sessions);

    // Act
    await controller.reload();

    // Assert
    expect(failed.error, isA<NetworkFailure>());
    expect(container.read(sessionsControllerProvider).value, sessions);
  });
}
