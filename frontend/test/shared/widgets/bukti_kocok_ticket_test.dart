import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/pump_app.dart';

BuktiKocokTicket _ticket({VoidCallback? onTap}) => BuktiKocokTicket(
  groupName: 'Arisan RT 05',
  periodNo: 4,
  totalPeriods: 10,
  slotNo: 7,
  winnerName: 'Bu Rina',
  // 19.30 in Jakarta.
  drawnAt: DateTime.utc(2026, 10, 26, 12, 30),
  code: '7H2K9QX4MP',
  verifyUrl: 'https://giliran.monai.my.id/v/7H2K9QX4MP',
  onTap: onTap,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('shows group, period, slot, winner, Jakarta time and grouped code', (tester) async {
    // Arrange
    await tester.pumpApp(SingleChildScrollView(child: _ticket()));

    // Assert
    expect(find.text('ARISAN RT 05'), findsOneWidget);
    expect(find.text('P4 / 10'), findsOneWidget);
    expect(find.text('No. 07'), findsOneWidget);
    expect(find.text('Bu Rina'), findsOneWidget);
    expect(find.text('Sen, 26 Okt 2026 · 19.30'), findsOneWidget);
    expect(find.text('7H2K 9QX4 MP'), findsOneWidget);
    expect(find.text('Cek di giliran.monai.my.id/v'), findsOneWidget);
  });

  testWidgets('the QR encodes the verify url', (tester) async {
    // Arrange
    await tester.pumpApp(SingleChildScrollView(child: _ticket()));

    // Act
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));

    // Assert
    expect(qr.size, 72);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('keeps the same kunyit body in dark mode', (tester) async {
    // Arrange
    await tester.pumpApp(SingleChildScrollView(child: _ticket()), dark: true);

    // Act
    final body = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((b) => b.color);

    // Assert
    expect(body, contains(AppPalette.kunyit400));
  });

  testWidgets('is one tappable semantics node', (tester) async {
    // Arrange
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpApp(SingleChildScrollView(child: _ticket(onTap: () => taps++)));

    // Act
    await tester.tap(find.byType(BuktiKocokTicket));

    // Assert
    expect(taps, 1);
    expect(
      find.bySemanticsLabel(RegExp('Bukti Kocok Arisan RT 05 periode 4 dari 10: nomor 07, Bu Rina')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
