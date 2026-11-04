import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/themes/themes.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> pumpMeter(WidgetTester tester, {int overdue = 1, bool showOverdue = true}) => tester.pumpApp(
    SizedBox(
      width: 320,
      child: ObligationMeter(
        name: 'Pak Dedi',
        wonPeriodNo: 3,
        periodsAfterWin: 7,
        remainingCount: 7,
        remainingAmount: 1400000,
        overdueCount: overdue,
        overdueAmount: overdue * 200000,
        showOverdue: showOverdue,
      ),
    ),
  );

  List<Color?> segmentColors(WidgetTester tester) => [
    for (final box in tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byType(ObligationMeter), matching: find.byType(DecoratedBox)),
    ))
      (box.decoration as ShapeDecoration).color,
  ];

  testWidgets('labels the win and what is left per period', (tester) async {
    // Act
    await pumpMeter(tester);

    // Assert
    expect(find.text('Sudah menang P3 · sisa 7 × Rp200.000', findRichText: true), findsOneWidget);
  });

  testWidgets('paints overdue segments in bata and the rest dashed', (tester) async {
    // Arrange
    await pumpMeter(tester, overdue: 2);
    final c = tester.element(find.byType(ObligationMeter)).colors;

    // Act
    final colors = segmentColors(tester);

    // Assert
    expect(colors, [c.rejected.fg, c.rejected.fg]);
    expect(
      find.descendant(of: find.byType(ObligationMeter), matching: find.byType(CustomPaint)),
      findsAtLeastNWidgets(5),
    );
  });

  testWidgets('paid periods use the paid color', (tester) async {
    // Arrange
    await tester.pumpApp(
      const SizedBox(
        width: 320,
        child: ObligationMeter(
          name: 'Bu Rina',
          wonPeriodNo: 2,
          periodsAfterWin: 8,
          remainingCount: 6,
          remainingAmount: 1200000,
        ),
      ),
    );
    final c = tester.element(find.byType(ObligationMeter)).colors;

    // Act
    final colors = segmentColors(tester);

    // Assert
    expect(colors, [c.paid.fg, c.paid.fg]);
  });

  testWidgets('the overdue line shows only in the organizer view', (tester) async {
    // Act
    await pumpMeter(tester, showOverdue: false);

    // Assert
    expect(find.textContaining('Terlambat'), findsNothing);
  });

  testWidgets('screen readers hear the whole meter', (tester) async {
    // Act
    await pumpMeter(tester);

    // Assert
    expect(
      find.bySemanticsLabel('Pak Dedi: sudah menang periode 3, sisa 7 iuran, 1 terlambat'),
      findsOneWidget,
    );
  });
}
