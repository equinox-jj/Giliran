import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/l10n/locale_controller.dart';
import 'package:giliran/core/storage/preferences.dart';
import 'package:giliran/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:giliran/features/settings/domain/entities/user_settings.dart';
import 'package:giliran/features/settings/presentation/settings/controllers/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_preferences.dart';
import '../../../../../helpers/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late FakePreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    repository = FakeSettingsRepository();
    prefs = FakePreferences();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    container.listen(settingsControllerProvider, (_, _) {});
    await container.read(settingsControllerProvider.future);
  });

  test('a toggle applies and saves only that field', () async {
    // Arrange
    const patch = UserSettingsPatch(notifyGroupActivity: true);

    // Act
    final failure = await container.read(settingsControllerProvider.notifier).change(patch);

    // Assert
    expect(failure, isNull);
    expect(repository.patches, [patch]);
    expect(container.read(settingsControllerProvider).value?.notifyGroupActivity, isTrue);
  });

  test('a rejected toggle reverts and returns the failure', () async {
    // Arrange
    repository.updateResult = const Left(Failure.network());

    // Act
    final failure = await container
        .read(settingsControllerProvider.notifier)
        .change(const UserSettingsPatch(notifyPaymentReminders: false));

    // Assert
    expect(failure, isA<NetworkFailure>());
    expect(container.read(settingsControllerProvider).value?.notifyPaymentReminders, isTrue);
  });

  test('setLanguage saves on the account and switches the app locale', () async {
    // Arrange
    await container.read(localeControllerProvider.future);

    // Act
    await container.read(settingsControllerProvider.notifier).setLanguage('en');

    // Assert
    expect(repository.patches, [const UserSettingsPatch(language: 'en')]);
    expect(container.read(localeControllerProvider).value, const Locale('en'));
    expect(prefs.language, 'en');
  });

  test('a rejected language keeps the app locale', () async {
    // Arrange
    await container.read(localeControllerProvider.future);
    repository.updateResult = const Left(Failure.network());

    // Act
    await container.read(settingsControllerProvider.notifier).setLanguage('en');

    // Assert
    expect(container.read(localeControllerProvider).value, const Locale('id'));
  });

  test('clearImageCache runs the clear', () async {
    // Arrange
    final notifier = container.read(settingsControllerProvider.notifier);

    // Act
    final failure = await notifier.clearImageCache();

    // Assert
    expect(failure, isNull);
    expect(repository.clearCalls, 1);
  });

  group('saved settings', () {
    const saved = UserSettings(
      language: 'id',
      notifyPaymentReminders: false,
      notifyDrawResults: false,
      notifyGroupActivity: false,
    );
    late ProviderContainer cached;

    setUp(() {
      repository.cachedResult = const Right(saved);
      repository.getSettingsGate = Completer<void>();
      cached = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          preferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(cached.dispose);
      cached.listen(settingsControllerProvider, (_, _) {});
    });

    test('show before the server answers', () async {
      // Arrange
      final gate = repository.getSettingsGate!;

      // Act
      final first = await cached.read(settingsControllerProvider.future);

      // Assert
      expect(first, saved);
      expect(gate.isCompleted, isFalse);
    });

    test('are replaced by the server copy once it loads', () async {
      // Arrange
      await cached.read(settingsControllerProvider.future);

      // Act
      repository.getSettingsGate!.complete();
      await pumpEventQueue();

      // Assert
      expect(cached.read(settingsControllerProvider).value, repository.settingsResult.getRight().toNullable());
    });

    test('stay when the server cannot be reached', () async {
      // Arrange
      await cached.read(settingsControllerProvider.future);
      repository.settingsResult = const Left(Failure.network());

      // Act
      repository.getSettingsGate!.complete();
      await pumpEventQueue();

      // Assert
      expect(cached.read(settingsControllerProvider), const AsyncData(saved));
    });

    test('a toggle made while the server loads is not overwritten', () async {
      // Arrange
      await cached.read(settingsControllerProvider.future);
      repository.updateResult = const Right(saved);
      await cached.read(settingsControllerProvider.notifier).change(const UserSettingsPatch(notifyGroupActivity: true));

      // Act
      repository.getSettingsGate!.complete();
      await pumpEventQueue();

      // Assert
      expect(cached.read(settingsControllerProvider).value, saved);
    });
  });

  test('with nothing saved and no server, loading fails', () async {
    // Arrange
    repository
      ..cachedResult = const Right(null)
      ..settingsResult = const Left(Failure.network());
    final fresh = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        preferencesProvider.overrideWithValue(prefs),
      ],
      retry: (_, _) => null,
    );
    addTearDown(fresh.dispose);
    fresh.listen(settingsControllerProvider, (_, _) {});

    // Act
    final call = fresh.read(settingsControllerProvider.future);

    // Assert
    await expectLater(call, throwsA(isA<NetworkFailure>()));
  });
}
