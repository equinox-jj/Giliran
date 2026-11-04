import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/history/data/repositories/history_repository_impl.dart';
import 'package:giliran/features/history/domain/entities/activity_entry.dart';
import 'package:giliran/features/history/presentation/activity_tab/widgets/activity_tab.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../helpers/fake_history_repository.dart';
import '../../../../../helpers/pump_app.dart';

/// Now: Tue 3 Nov 2026, 10.00 in Jakarta.
final _now = DateTime.utc(2026, 11, 3, 3);

ActivityEntry _approved(String id, DateTime at) => ActivityEntry(
  id: id,
  action: 'payment.approved',
  actor: const UserSummary(id: 'u1', name: 'Bu Rina'),
  subject: MemberRef(id: 'm$id', displayName: 'Anggota $id', slotNo: 1),
  createdAt: at,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeHistoryRepository repository;

  setUp(() => repository = FakeHistoryRepository());

  Future<void> pumpTab(WidgetTester tester, {bool settle = true}) async {
    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      const Scaffold(
        body: CustomScrollView(slivers: [ActivityTab(groupId: 'g1')]),
      ),
      container: container,
    );
    // The loading row's skeleton animates, so a pending page never settles.
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('groups rows under Hari ini, Kemarin and a date', (tester) async {
    // Arrange
    repository.first = [
      _approved('3', DateTime.utc(2026, 11, 3, 2)),
      _approved('2', DateTime.utc(2026, 11, 2, 12, 30)),
      _approved('1', DateTime.utc(2026, 10, 31, 1)),
    ];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Semua perubahan oleh pengurus tercatat di sini dan tidak bisa dihapus.'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('Sab, 31 Okt'), findsOneWidget);
    expect(find.text('Bu Rina menyetujui bayaran Anggota 2'), findsOneWidget);
    expect(find.text('19.30'), findsOneWidget);
  });

  testWidgets('the last page ends with "Ini awal riwayat grup."', (tester) async {
    // Arrange
    repository.first = [_approved('1', DateTime.utc(2026, 11, 3, 2))];

    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Ini awal riwayat grup.'), findsOneWidget);
  });

  testWidgets('scrolling to the end loads each next_cursor once', (tester) async {
    // Arrange
    repository
      ..first = [for (var i = 0; i < 30; i++) _approved('a$i', DateTime.utc(2026, 11, 3, 2, 59 - i))]
      ..firstCursor = const ActivityCursor(nextCursor: 'c1', hasMore: true)
      ..pages['c1'] = (
        [for (var i = 0; i < 30; i++) _approved('b$i', DateTime.utc(2026, 11, 2, 2, 59 - i))],
        const ActivityCursor(nextCursor: 'c2', hasMore: true),
      )
      ..pages['c2'] = ([_approved('c0', DateTime.utc(2026, 11, 1, 2))], const ActivityCursor());
    await pumpTab(tester);
    expect(repository.loadedCursors, isEmpty);

    // Act
    await tester.scrollUntilVisible(find.text('Ini awal riwayat grup.'), 600);
    await tester.pumpAndSettle();

    // Assert
    expect(repository.loadedCursors, ['c1', 'c2']);
    expect(find.text('Ini awal riwayat grup.'), findsOneWidget);
  });

  testWidgets('a visible end row loads page 2 once the refresh brings its cursor', (tester) async {
    // Arrange
    final cached = [_approved('2', DateTime.utc(2026, 11, 3, 2)), _approved('1', DateTime.utc(2026, 11, 3, 1))];
    repository
      ..cached = cached
      ..first = cached
      ..firstCursor = const ActivityCursor(nextCursor: 'c1', hasMore: true)
      ..pages['c1'] = ([_approved('0', DateTime.utc(2026, 11, 2, 1))], const ActivityCursor())
      ..refreshGate = Completer<void>();
    await pumpTab(tester, settle: false);
    expect(find.text('Bu Rina menyetujui bayaran Anggota 2'), findsOneWidget);

    // Act
    repository.refreshGate!.complete();
    await tester.pumpAndSettle();

    // Assert
    expect(repository.loadedCursors, ['c1']);
    expect(find.text('Ini awal riwayat grup.'), findsOneWidget);
  });

  testWidgets('an empty log shows the empty state', (tester) async {
    // Act
    await pumpTab(tester);

    // Assert
    expect(find.text('Belum ada aktivitas di grup ini.'), findsOneWidget);
    expect(find.byType(ActivityRow), findsNothing);
  });
}
