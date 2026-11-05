import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/services/secure_screen_controller.dart';
import 'package:giliran/core/services/secure_window_service.dart';
import 'package:giliran/core/storage/preferences.dart';

import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_secure_window_service.dart';

void main() {
  late FakePreferences prefs;
  late FakeSecureWindowService window;
  late ProviderContainer container;

  setUp(() {
    prefs = FakePreferences();
    window = FakeSecureWindowService();
    container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        secureWindowServiceProvider.overrideWithValue(window),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('applies the saved setting to the window on start', () async {
    // Arrange
    prefs.secureScreen = true;

    // Act
    final value = await container.read(secureScreenControllerProvider.future);

    // Assert
    expect(value, isTrue);
    expect(window.calls, [true]);
  });

  test('is off by default and leaves the window alone', () async {
    // Arrange
    // FakePreferences starts with secureScreen false.

    // Act
    final value = await container.read(secureScreenControllerProvider.future);

    // Assert
    expect(value, isFalse);
    expect(window.calls, isEmpty);
  });

  test('set saves the choice and secures the window', () async {
    // Arrange
    await container.read(secureScreenControllerProvider.future);

    // Act
    await container.read(secureScreenControllerProvider.notifier).set(true);

    // Assert
    expect(prefs.secureScreen, isTrue);
    expect(window.calls, [true]);
    expect(container.read(secureScreenControllerProvider).value, isTrue);
  });
}
