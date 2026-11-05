import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

RecapCard _card({List<String> unpaid = const ['Pak Dedi', 'Bu Ani'], String? account = 'BCA 1234567890 a.n. Rina'}) =>
    RecapCard(
      groupName: 'Arisan RT 05',
      periodNo: 4,
      totalPeriods: 10,
      paidCount: 10 - unpaid.length,
      totalCount: 10,
      collectedAmount: (10 - unpaid.length) * 200000,
      expectedAmount: 2000000,
      unpaidNames: unpaid,
      dueDate: DateTime.utc(2026, 10, 24),
      drawDate: DateTime.utc(2026, 10, 25),
      account: account,
      tone: GiliranColors.exportTones[0],
      now: DateTime.utc(2026, 10, 20),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<void> pumpCard(WidgetTester tester, RecapCard card, {bool dark = false}) => tester.pumpApp(
    Center(child: RecapExportFrame(card: card)),
    dark: dark,
  );

  testWidgets('shows the period, the amounts, the unpaid names and the facts', (tester) async {
    // Act
    await pumpCard(tester, _card());

    // Assert
    expect(find.text('ARISAN RT 05'), findsOneWidget);
    expect(find.text('Periode 4 dari 10'), findsOneWidget);
    expect(find.text('Rp1.600.000'), findsOneWidget);
    expect(find.text('dari Rp2.000.000'), findsOneWidget);
    expect(find.text('Belum bayar:'), findsOneWidget);
    expect(find.text('• Pak Dedi  • Bu Ani'), findsOneWidget);
    expect(find.text('Sab, 24 Okt'), findsOneWidget);
    expect(find.text('Min, 25 Okt'), findsOneWidget);
    expect(find.text('BCA 1234567890 a.n. Rina'), findsOneWidget);
    expect(find.text('dibuat dengan Giliran'), findsOneWidget);
  });

  testWidgets('lists at most 8 names, then "+n lainnya"', (tester) async {
    // Act
    await pumpCard(tester, _card(unpaid: [for (var n = 1; n <= 10; n++) 'Anggota $n'], account: null));

    // Assert
    final text = tester.widget<Text>(find.textContaining('• Anggota 1 ')).data!;
    expect(text, contains('• Anggota 8'));
    expect(text, isNot(contains('Anggota 9')));
    expect(text, endsWith('+2 lainnya'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('never shows a phone number', (tester) async {
    // Act
    await pumpCard(tester, _card());

    // Assert
    expect(find.textContaining(RegExp(r'(\+62|\b08)\d{8,}')), findsNothing);
  });

  testWidgets('everyone paid replaces the list with "Semua sudah bayar ✓"', (tester) async {
    // Act
    await pumpCard(tester, _card(unpaid: const []));

    // Assert
    expect(find.text('Semua sudah bayar ✓'), findsOneWidget);
    expect(find.text('Belum bayar:'), findsNothing);
  });

  testWidgets('stays light in dark mode', (tester) async {
    // Act
    await pumpCard(tester, _card(), dark: true);

    // Assert
    final context = tester.element(find.text('Periode 4 dari 10'));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('a long account and long names fit the export frame', (tester) async {
    // Act
    await pumpCard(
      tester,
      _card(
        unpaid: [for (var n = 1; n <= 12; n++) 'Ibu Kartika Sari Dewi $n'],
        account: 'Bank Rakyat Indonesia 123456789012345 a.n. Kartika Sari Dewi Lestari',
      ),
    );

    // Assert
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RecapExportFrame)), RecapExportFrame.size);
  });
}
