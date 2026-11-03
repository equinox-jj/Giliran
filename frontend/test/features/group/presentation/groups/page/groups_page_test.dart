import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_list_filter.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/presentation/groups/page/groups_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/group_fixtures.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late List<String> opened;

  setUp(() {
    groups = FakeGroupRepository();
    opened = [];
  });

  Future<void> pumpGroups(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [groupRepositoryProvider.overrideWithValue(groups)]);
    addTearDown(container.dispose);
    await tester.pumpPage(
      GroupsPage(
        onOpenGroup: (id) => opened.add('group:$id'),
        onCreateGroup: () => opened.add('create'),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the groups as full-width cards and opens one', (tester) async {
    // Arrange
    groups.groups = [summary('a', name: 'Arisan RT 05')];
    await pumpGroups(tester);

    // Act
    await tester.tap(find.text('Arisan RT 05'));

    // Assert
    final card = tester.widget<GroupCard>(find.byType(GroupCard));
    expect(card.layout, GroupCardLayout.list);
    expect(opened, ['group:a']);
  });

  testWidgets('Selesai switches the list filter', (tester) async {
    // Arrange
    await pumpGroups(tester);

    // Act
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    // Assert
    expect(groups.watchedFilters.last, GroupListFilter.finished);
    expect(groups.refreshedFilters, contains(GroupListFilter.finished));
  });

  testWidgets('the empty copy follows the segment', (tester) async {
    // Arrange
    await pumpGroups(tester);
    final activeEmpty = find.text('Belum ada arisan aktif').evaluate().isNotEmpty;

    // Act
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    // Assert
    expect(activeEmpty, isTrue);
    expect(find.text('Belum ada arisan yang selesai'), findsOneWidget);
  });

  testWidgets('role chips filter locally and toggle off', (tester) async {
    // Arrange
    groups.groups = [
      summary('org', name: 'Arisan Pengurus', role: MemberRole.organizer),
      summary('mem', name: 'Arisan Anggota'),
    ];
    await pumpGroups(tester);
    final refreshes = groups.refreshedFilters.length;

    // Act
    await tester.tap(find.widgetWithText(AppChip, 'Saya anggota'));
    await tester.pumpAndSettle();
    final onlyMember = find.text('Arisan Pengurus').evaluate().isEmpty;
    await tester.tap(find.widgetWithText(AppChip, 'Saya anggota'));
    await tester.pumpAndSettle();

    // Assert
    expect(onlyMember, isTrue);
    expect(find.text('Arisan Pengurus'), findsOneWidget);
    expect(groups.refreshedFilters.length, refreshes);
  });

  testWidgets('the Buat grup pill opens Create group', (tester) async {
    // Arrange
    groups.groups = [summary('a')];
    await pumpGroups(tester);

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Buat grup'));

    // Assert
    expect(opened, ['create']);
  });

  testWidgets('the empty state keeps its own Buat grup and hides the pill', (tester) async {
    // Arrange
    groups.groups = [];

    // Act
    await pumpGroups(tester);

    // Assert
    expect(find.text('Belum ada arisan aktif'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Buat grup'), findsOneWidget);
  });
}
