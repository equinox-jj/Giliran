import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

List<PeriodTokenData> _periods(int count, int current) => [
  for (var n = 1; n <= count; n++)
    PeriodTokenData(
      id: 'p$n',
      periodNo: n,
      state: n < current
          ? SlotTokenState.done
          : n == current
          ? SlotTokenState.current
          : SlotTokenState.upcoming,
    ),
];

void main() {
  testWidgets('centers the current token on phones', (tester) async {
    // Arrange
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Act
    await tester.pumpApp(
      SizedBox(
        width: 350,
        child: PeriodStrip(periods: _periods(30, 20), onSelect: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Assert
    final current = tester.getCenter(find.bySemanticsLabel('Periode 20, sedang berjalan'));
    expect(current.dx, closeTo(390 / 2, PeriodStrip.itemExtent));
  });

  testWidgets('tapping a token selects its period', (tester) async {
    // Arrange
    String? selected;
    await tester.pumpApp(
      SizedBox(
        width: 350,
        child: PeriodStrip(periods: _periods(4, 2), onSelect: (id) => selected = id),
      ),
    );
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.bySemanticsLabel('Periode 1, selesai'));

    // Assert
    expect(selected, 'p1');
  });
}
