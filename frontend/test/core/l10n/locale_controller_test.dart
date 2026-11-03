import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/l10n/locale_controller.dart';
import 'package:giliran/core/storage/preferences.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_preferences.dart';

void main() {
  late FakePreferences prefs;
  late ProviderContainer container;

  setUp(() {
    prefs = FakePreferences();
    container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() => container.dispose());

  test('defaults to Indonesian and persists a switch to English', () async {
    // Arrange
    final initial = await container.read(localeControllerProvider.future);

    // Act
    await container.read(localeControllerProvider.notifier).set(const Locale('en'));

    // Assert
    expect(initial, const Locale('id'));
    expect(container.read(localeControllerProvider).value, const Locale('en'));
    expect(prefs.language, 'en');
  });

  test('reads a stored English choice', () async {
    // Arrange
    prefs.language = 'en';

    // Act
    final locale = await container.read(localeControllerProvider.future);

    // Assert
    expect(locale, const Locale('en'));
  });

  test('falls back to Indonesian for an unknown stored code', () async {
    // Arrange
    prefs.language = 'fr';

    // Act
    final locale = await container.read(localeControllerProvider.future);

    // Assert
    expect(locale, const Locale('id'));
  });
}
