import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/session_manager.dart';
import 'package:giliran/features/auth/domain/entities/auth_status.dart';
import 'package:giliran/features/auth/presentation/shared/controllers/auth_session_controller.dart';
import 'package:giliran/features/profile/domain/entity/profile.dart';

import '../../../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  final user = ProfileData(name: 'Ana', pinSet: true);

  setUp(
    () => repository = FakeAuthRepository()..userResult = Right(user),
  );

  test('locks a complete session on launch', () async {
    // Arrange
    final container = authTestContainer(repository);

    // Act
    final status = await container.read(authSessionControllerProvider.future);

    // Assert
    expect(status, AuthStatus.locked(user: user));
  });

  test('unlock opens a locked session and lock closes it again', () async {
    // Arrange
    final container = authTestContainer(repository);
    await container.read(authSessionControllerProvider.future);
    final controller = container.read(authSessionControllerProvider.notifier);

    // Act
    controller.unlock();
    final unlocked = container.read(authSessionControllerProvider).value;
    controller.lock();
    final locked = container.read(authSessionControllerProvider).value;

    // Assert
    expect(unlocked, AuthStatus.unlocked(user: user));
    expect(locked, AuthStatus.locked(user: user));
  });

  test('refresh with unlocked skips the lock', () async {
    // Arrange
    final container = authTestContainer(repository);
    await container.read(authSessionControllerProvider.future);

    // Act
    await container.read(authSessionControllerProvider.notifier).refresh(unlocked: true);

    // Assert
    expect(
      container.read(authSessionControllerProvider).value,
      AuthStatus.unlocked(user: user),
    );
  });

  test('signs out with expired when the session expires', () async {
    // Arrange
    final container = authTestContainer(repository);
    await container.read(authSessionControllerProvider.future);

    // Act
    container.read(sessionManagerProvider).notifyExpired();
    await Future<void>.delayed(Duration.zero);

    // Assert
    expect(
      container.read(authSessionControllerProvider).value,
      const AuthStatus.signedOut(expired: true),
    );
  });

  test('logout clears the device and signs out', () async {
    // Arrange
    final container = authTestContainer(repository);
    await container.read(authSessionControllerProvider.future);

    // Act
    final failure = await container.read(authSessionControllerProvider.notifier).logout();

    // Assert
    expect(failure, isNull);
    expect(repository.calls, containsAllInOrder(['logout', 'clearSession']));
    expect(
      container.read(authSessionControllerProvider).value,
      const AuthStatus.signedOut(),
    );
  });

  test('surfaces a failed session read as an error', () async {
    // Arrange
    repository.hasSessionResult = const Left(Failure.cache());
    final container = authTestContainer(repository);

    // Act
    final read = container.read(authSessionControllerProvider.future);

    // Assert
    await expectLater(read, throwsA(isA<CacheFailure>()));
  });

  group('lockIfIdle', () {
    final hiddenAt = DateTime(2026, 11, 2, 9);

    Future<ProviderContainer> unlockedContainer() async {
      final container = authTestContainer(repository);
      await container.read(authSessionControllerProvider.future);
      container.read(authSessionControllerProvider.notifier).unlock();
      return container;
    }

    test('locks after five minutes in the background', () async {
      // Arrange
      final container = await unlockedContainer();

      // Act
      await container
          .read(authSessionControllerProvider.notifier)
          .lockIfIdle(hiddenAt, now: hiddenAt.add(const Duration(minutes: 5)));

      // Assert
      expect(
        container.read(authSessionControllerProvider).value,
        AuthStatus.locked(user: user),
      );
    });

    test('stays open after a shorter time away', () async {
      // Arrange
      final container = await unlockedContainer();

      // Act
      await container
          .read(authSessionControllerProvider.notifier)
          .lockIfIdle(hiddenAt, now: hiddenAt.add(const Duration(minutes: 4, seconds: 59)));

      // Assert
      expect(
        container.read(authSessionControllerProvider).value,
        AuthStatus.unlocked(user: user),
      );
    });
  });
}
