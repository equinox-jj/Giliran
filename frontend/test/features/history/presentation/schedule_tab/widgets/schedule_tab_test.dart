import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/history/presentation/schedule_tab/widgets/schedule_tab.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/pump_app.dart';

const _group = GroupDetail(id: 'g1', name: 'Arisan RT 05', status: GroupStatus.active, totalSlots: 10);

List<Period> _periods() => [
  for (var n = 1; n <= 10; n++)
    Period(
      id: 'p$n',
      periodNo: n,
      drawDate: DateTime.utc(2026, n, 5),
      dueDate: DateTime.utc(2026, n, 5),
      status: n <= 4
          ? PeriodStatus.drawn
          : n == 5
          ? PeriodStatus.open
          : PeriodStatus.upcoming,
      winner: n <= 4 ? MemberRef(id: 'm$n', displayName: n == 4 ? 'Bu Rina' : 'Pemenang $n') : null,
    ),
];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late List<String> opened;

  setUp(() => opened = []);

  Future<void> pumpTab(WidgetTester tester, {List<Period>? periods}) async {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => DateTime.utc(2026, 4, 20, 3))],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      Scaffold(
        body: CustomScrollView(
          slivers: [
            ScheduleTab(group: _group, periods: periods ?? _periods(), onBuktiKocok: opened.add),
          ],
        ),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('today pill shows cycle completion, 40% for 4 of 10', (tester) async {
    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('drawn rows read "P4 · {winner}" with a Bukti link to S38', (tester) async {
    // Arrange
    await pumpTab(tester);
    final row = find.ancestor(
      of: find.text('Dikocok Min, 5 Apr'),
      matching: find.byKey(const ValueKey('schedule-row-p4')),
    );
    expect(find.descendant(of: row, matching: find.text('P4 · Bu Rina')), findsOneWidget);

    // Act
    await tester.tap(find.descendant(of: row, matching: find.text('Bukti')));

    // Assert
    expect(opened, ['p4']);
  });

  testWidgets('undrawn rows read "Belum dikocok" and have no Bukti link', (tester) async {
    // Act
    await pumpTab(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('schedule-row-p6')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Assert
    final row = find.byKey(const ValueKey('schedule-row-p6'));
    expect(find.descendant(of: row, matching: find.text('Belum dikocok')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Bukti')), findsNothing);
  });

  testWidgets('segmented Periode · Bulan switches the axis to months', (tester) async {
    // Arrange
    await pumpTab(tester);
    expect(find.text('Feb'), findsNothing);

    // Act
    await tester.tap(find.text('Bulan'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Feb'), findsOneWidget);
    final timeline = tester.widget<JadwalTimeline>(find.byType(JadwalTimeline));
    expect(timeline.ticks, isNotEmpty);
  });

  testWidgets('a group without periods shows the empty state', (tester) async {
    // Act
    await pumpTab(tester, periods: const []);

    // Assert
    expect(find.text('Jadwal muncul setelah arisan dimulai.'), findsOneWidget);
    expect(find.byType(JadwalTimeline), findsNothing);
  });
}
