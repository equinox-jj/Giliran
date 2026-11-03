import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/constants/app_icons.dart';
import 'package:giliran/features/home/domain/entities/agenda_day.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

List<AgendaDay> _week() => [
  for (var i = 0; i < 7; i++)
    AgendaDay(
      date: DateTime.utc(2026, 11, 2 + i),
      isToday: i == 2,
      events: [
        if (i == 3) const AgendaEvent(kind: AgendaEventKind.due, groupId: 'g1', groupName: 'Arisan RT 05'),
        if (i == 3) const AgendaEvent(kind: AgendaEventKind.draw, groupId: 'g1', groupName: 'Arisan RT 05'),
      ],
    ),
];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('a day with a due date and a draw shows the due icon', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: AgendaStrip(days: _week(), onSelect: (_) {}),
      ),
    );

    // Assert
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.asset == AppIcons.receipt), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.asset == AppIcons.shuffle), findsNothing);
  });

  testWidgets('reads the day and its events', (tester) async {
    // Arrange
    final handle = tester.ensureSemantics();

    // Act
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: AgendaStrip(days: _week(), onSelect: (_) {}),
      ),
    );

    // Assert
    expect(
      find.bySemanticsLabel('Kam, 5 Nov: Jatuh tempo Arisan RT 05, Kocokan Arisan RT 05'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Hari ini, Rab, 4 Nov')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('fits seven days on a narrow phone without overflowing', (tester) async {
    // Act
    await tester.pumpApp(
      SizedBox(
        width: 288,
        child: AgendaStrip(days: _week(), onSelect: (_) {}),
      ),
    );

    // Assert
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a day selects it', (tester) async {
    // Arrange
    int? selected;
    await tester.pumpApp(
      SizedBox(
        width: 360,
        child: AgendaStrip(days: _week(), onSelect: (i) => selected = i),
      ),
    );

    // Act
    await tester.tap(find.text('Jum'));

    // Assert
    expect(selected, 4);
  });
}
