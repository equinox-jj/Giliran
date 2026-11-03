import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/storage/preferences.dart';
import 'package:giliran/core/themes/theme_mode_controller.dart';
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

  test('defaults to system and persists dark', () async {
    // Arrange
    final initial = await container.read(themeModeControllerProvider.future);

    // Act
    await container.read(themeModeControllerProvider.notifier).set(ThemeMode.dark);

    // Assert
    expect(initial, ThemeMode.system);
    expect(container.read(themeModeControllerProvider).value, ThemeMode.dark);
    expect(prefs.themeMode, 'dark');
  });

  test('reads a stored light choice', () async {
    // Arrange
    prefs.themeMode = 'light';

    // Act
    final mode = await container.read(themeModeControllerProvider.future);

    // Assert
    expect(mode, ThemeMode.light);
  });

  test('falls back to system for an unknown stored value', () async {
    // Arrange
    prefs.themeMode = 'sepia';

    // Act
    final mode = await container.read(themeModeControllerProvider.future);

    // Assert
    expect(mode, ThemeMode.system);
  });
}
