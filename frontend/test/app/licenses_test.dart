import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the Phosphor and both OFL font licenses', () async {
    // Arrange
    registerAppLicenses();

    // Act
    final entries = await LicenseRegistry.licenses.toList();
    final packages = {for (final e in entries) ...e.packages};
    final phosphor = entries.firstWhere((e) => e.packages.contains(AppLicenses.phosphor));

    // Assert
    expect(
      packages,
      containsAll([AppLicenses.phosphor, AppLicenses.plusJakartaSans, AppLicenses.jetBrainsMono]),
    );
    expect(phosphor.paragraphs.map((p) => p.text).join('\n'), contains('MIT License'));
  });
}
