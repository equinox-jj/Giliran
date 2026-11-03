import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('the current device shows the pill and no Keluarkan', (tester) async {
    // Arrange
    const row = SessionRow(deviceName: 'Pixel 8', platform: 'android', current: true);

    // Act
    await tester.pumpApp(const SizedBox(width: 360, child: row));

    // Assert
    expect(find.text('Perangkat ini'), findsOneWidget);
    expect(find.text('Keluarkan'), findsNothing);
  });

  testWidgets('another device shows when it was last active', (tester) async {
    // Arrange
    final row = SessionRow(
      deviceName: 'iPhone 15',
      platform: 'ios',
      lastActiveAt: DateTime.utc(2026, 11, 3, 8),
      now: DateTime.utc(2026, 11, 3, 10),
      onSignOut: () {},
    );

    // Act
    await tester.pumpApp(SizedBox(width: 360, child: row));

    // Assert
    expect(find.text('Aktif 2 jam lalu'), findsOneWidget);
    expect(find.text('Keluarkan'), findsOneWidget);
  });

  testWidgets('Keluarkan asks first and cancelling keeps the session', (tester) async {
    // Arrange
    var signedOut = 0;
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: SessionRow(deviceName: 'iPhone 15', onSignOut: () => signedOut++),
      ),
    );

    // Act
    await tester.tap(find.text('Keluarkan'));
    await tester.pumpAndSettle();
    final asked = find.text('Keluarkan iPhone 15?').evaluate().isNotEmpty;
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Assert
    expect(asked, isTrue);
    expect(signedOut, 0);
  });

  testWidgets('a nameless device gets the fallback name', (tester) async {
    // Arrange
    const row = SessionRow(deviceName: null, current: true);

    // Act
    await tester.pumpApp(const SizedBox(width: 360, child: row));

    // Assert
    expect(find.text('Perangkat tanpa nama'), findsOneWidget);
  });
}
