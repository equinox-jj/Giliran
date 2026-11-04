import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  late List<String> proofs;

  setUp(() => proofs = []);

  Widget card({int drawn = 3, int total = 3}) => SingleChildScrollView(
    child: SizedBox(
      width: 360,
      child: CycleSummaryCard(
        headline: 'Arisan selesai. **3 periode, 3 pemenang.**',
        stats: const [
          CycleStat(value: 'Rp1.800.000', label: 'Terkumpul'),
          CycleStat(value: '100%', label: 'Iuran lunas'),
          CycleStat(value: '3', label: 'Anggota'),
        ],
        tokens: [
          for (var n = 1; n <= total; n++)
            PeriodTokenData(
              id: 'p$n',
              periodNo: n,
              state: n <= drawn ? SlotTokenState.done : SlotTokenState.upcoming,
              winnerName: n <= drawn ? 'Pemenang $n' : null,
            ),
        ],
        winners: [
          for (var n = 1; n <= drawn; n++) CycleWinnerRow(periodId: 'p$n', title: 'P$n · Pemenang $n', date: '5 Jan'),
        ],
        onProof: proofs.add,
      ),
    ),
  );

  testWidgets('shows the headline, the three figures and the winners', (tester) async {
    // Act
    await tester.pumpApp(card());

    // Assert
    expect(find.textContaining('Arisan selesai.'), findsOneWidget);
    expect(find.text('Rp1.800.000'), findsOneWidget);
    expect(find.text('Iuran lunas'), findsOneWidget);
    expect(find.text('Pemenang per periode'), findsOneWidget);
    expect(find.text('P2 · Pemenang 2'), findsOneWidget);
    expect(find.byType(SlotToken), findsNWidgets(3));
  });

  testWidgets('a winner row links to its Bukti Kocok', (tester) async {
    // Arrange
    await tester.pumpApp(card());

    // Act
    await tester.tap(find.text('Bukti').at(1));

    // Assert
    expect(proofs, ['p2']);
  });

  testWidgets('undrawn periods are dashed and marked Tidak dikocok', (tester) async {
    // Act
    await tester.pumpApp(card(drawn: 1, total: 3));

    // Assert
    expect(find.text('Tidak dikocok'), findsNWidgets(2));
    final upcoming = tester
        .widgetList<SlotToken>(find.byType(SlotToken))
        .where((t) => t.state == SlotTokenState.upcoming);
    expect(upcoming, hasLength(2));
  });
}
