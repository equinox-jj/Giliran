import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('shows the last sync time in Jakarta', (tester) async {
    // Arrange
    final lastSynced = DateTime.utc(2026, 11, 3, 12, 2);

    // Act
    await tester.pumpApp(OfflineBanner(lastSyncedAt: lastSynced));

    // Assert
    expect(find.text('Offline. Data terakhir 19.02.'), findsOneWidget);
  });

  testWidgets('shows only "Offline." before the first sync', (tester) async {
    // Arrange
    const banner = OfflineBanner(lastSyncedAt: null);

    // Act
    await tester.pumpApp(banner);

    // Assert
    expect(find.text('Offline.'), findsOneWidget);
  });
}
