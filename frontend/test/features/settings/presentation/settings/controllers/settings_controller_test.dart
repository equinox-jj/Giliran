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
}
