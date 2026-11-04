import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

List<JadwalBar> _bars(int n, {int drawn = 4}) => [
  for (var i = 0; i < n; i++)
    JadwalBar(
      periodNo: i + 1,
      fill: i < drawn
          ? JadwalBarFill.drawn
          : i == drawn
          ? JadwalBarFill.open
          : JadwalBarFill.upcoming,
      start: i / n,
      end: (i + 1) / n,
      label: i < drawn ? 'P${i + 1} · Pemenang ${i + 1}' : 'P${i + 1}',
      semanticsLabel: 'Periode ${i + 1}',
      tone: i < drawn ? const Color(0xFF2E7D5B) : null,
    ),
];

void main() {
  testWidgets('shows the today pill with the cycle completion', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: JadwalTimeline(bars: _bars(10), todayAt: 0.45, todayLabel: '40%'),
      ),
    );

    // Assert
    expect(find.text('40%'), findsOneWidget);
    expect(find.byKey(JadwalTimeline.todayLineKey), findsOneWidget);
  });

  testWidgets('labels drawn bars with their winner', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: JadwalTimeline(bars: _bars(10), todayAt: 0.45, todayLabel: '40%'),
      ),
    );

    // Assert
    expect(find.text('P4 · Pemenang 4'), findsOneWidget);
  });

  testWidgets('shows at most five rows and scrolls to the rest', (tester) async {
    // Arrange
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: JadwalTimeline(bars: _bars(10), todayAt: 0.45, todayLabel: '40%'),
      ),
    );
    expect(find.text('P10'), findsNothing);

    // Act
    await tester.drag(find.byType(JadwalTimeline), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('P10'), findsOneWidget);
  });

  testWidgets('without a today position there is no today line', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: JadwalTimeline(bars: _bars(3), todayAt: null, todayLabel: '0%'),
      ),
    );

    // Assert
    expect(find.byKey(JadwalTimeline.todayLineKey), findsNothing);
  });

  testWidgets('month ticks show their labels', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: JadwalTimeline(
          bars: _bars(3),
          todayAt: 0.2,
          todayLabel: '10%',
          ticks: const [
            JadwalTick(at: 0.3, label: 'Jan'),
            JadwalTick(at: 0.6, label: 'Feb'),
          ],
        ),
      ),
    );

    // Assert
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Feb'), findsOneWidget);
  });

  testWidgets('each row reads its semantics label', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: JadwalTimeline(bars: _bars(3), todayAt: 0.2, todayLabel: '10%'),
      ),
    );

    // Assert
    expect(find.bySemanticsLabel('Periode 2'), findsOneWidget);
    handle.dispose();
  });
}
