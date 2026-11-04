import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/deep_link_controller.dart';

import '../helpers/fake_preferences.dart';

void main() {
  test('a pending link survives an app restart', () async {
    // Arrange
    final preferences = FakePreferences();
    DeepLinkController(preferences).remember('/j/K7P2QX9M');
    final restarted = DeepLinkController(preferences);

    // Act
    await restarted.restore();

    // Assert
    expect(restarted.pending, '/j/K7P2QX9M');
  });

  test('consuming clears the link in memory and in storage', () async {
    // Arrange
    final preferences = FakePreferences();
    final controller = DeepLinkController(preferences)..remember('/c/token');

    // Act
    final link = controller.consumePending();
    await Future<void>.delayed(Duration.zero);

    // Assert
    expect(link, '/c/token');
    expect(controller.pending, isNull);
    expect(controller.consumePending(), isNull);
    expect(preferences.pendingDeepLink, isNull);
  });

  test('a stored link does not replace one that arrived meanwhile', () async {
    // Arrange
    final preferences = FakePreferences()..pendingDeepLink = '/j/OLDCODE1';
    final controller = DeepLinkController(preferences)..remember('/j/NEWCODE2');

    // Act
    await controller.restore();

    // Assert
    expect(controller.pending, '/j/NEWCODE2');
  });
}
