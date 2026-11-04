import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/group/presentation/edit_group/page/edit_group_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/pump_app.dart';

const _group = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  periodType: PeriodType.monthly,
  totalSlots: 10,
  filledSlots: 10,
  drawMethod: DrawMethod.random,
  reminderDaysBefore: 2,
  status: GroupStatus.active,
  myRole: MemberRole.organizer,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late List<String> events;

  setUp(() {
    groups = FakeGroupRepository();
    events = [];
  });

  Future<void> pumpEdit(WidgetTester tester, GroupDetail group) async {
    groups.group = group;
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      EditGroupPage(
        groupId: 'g1',
        onPaymentInfo: () => events.add('paymentInfo'),
        onFixedOrder: () => events.add('fixedOrder'),
        onLeaveRequests: () => events.add('leaveRequests'),
        onTransfer: () => events.add('transfer'),
        onClosed: () => events.add('closed'),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  SettingsRow row(WidgetTester tester, String label) =>
      tester.widget<SettingsRow>(find.widgetWithText(SettingsRow, label));

  testWidgets('after start the group rules are locked', (tester) async {
    // Act
    await pumpEdit(tester, _group);

    // Assert
    for (final label in ['Iuran', 'Periode', 'Jumlah slot', 'Tanggal mulai', 'Cara kocokan']) {
      await tester.scrollUntilVisible(find.widgetWithText(SettingsRow, label), 100);
      expect(row(tester, label).onTap, isNull, reason: label);
    }
    expect(find.text('Terkunci setelah arisan dimulai, supaya adil untuk semua anggota.'), findsOneWidget);
  });

  testWidgets('a draft group can change its rules', (tester) async {
    // Act
    await pumpEdit(tester, _group.copyWith(status: GroupStatus.draft));

    // Assert
    expect(row(tester, 'Iuran').onTap, isNotNull);
    expect(find.text('Terkunci setelah arisan dimulai, supaya adil untuk semua anggota.'), findsNothing);
  });

  testWidgets('group_not_draft on save shows the lock caption', (tester) async {
    // Arrange
    groups.groupResult = const Left(Failure.conflict(code: ApiErrorCode.groupNotDraft));
    await pumpEdit(tester, _group.copyWith(status: GroupStatus.draft));
    await tester.tap(find.widgetWithText(SettingsRow, 'Jumlah slot'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Terkunci setelah arisan dimulai, supaya adil untuk semua anggota.'), findsOneWidget);
  });

  testWidgets('saving the name sends only the name', (tester) async {
    // Arrange
    await pumpEdit(tester, _group);
    await tester.tap(find.widgetWithText(SettingsRow, 'Nama grup'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(AppSheetBody), matching: find.byType(AppTextField)),
      'Arisan Baru',
    );

    // Act
    await tester.tap(find.widgetWithText(AppButton, 'Simpan'));
    await tester.pumpAndSettle();

    // Assert
    expect(groups.lastUpdate?.name, 'Arisan Baru');
    expect(groups.lastUpdate?.amount, isNull);
    expect(find.text('Tersimpan.'), findsOneWidget);
  });

  testWidgets('closing asks first, then closes the group', (tester) async {
    // Arrange
    await pumpEdit(tester, _group);
    await tester.scrollUntilVisible(find.widgetWithText(SettingsRow, 'Tutup grup'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingsRow, 'Tutup grup'));
    await tester.pumpAndSettle();
    final asked =
        find.text('Tutup Arisan RT 05?').evaluate().isNotEmpty &&
        find.text('Grup jadi arsip dan tidak bisa dibuka lagi.').evaluate().isNotEmpty;

    // Act
    await tester.tap(find.text('Tutup grup').last);
    await tester.pumpAndSettle();

    // Assert
    expect(asked, isTrue);
    expect(groups.calls, contains('closeGroup'));
    expect(events, ['closed']);
  });

  testWidgets('a co-organizer has no danger zone', (tester) async {
    // Act
    await pumpEdit(tester, _group.copyWith(myRole: MemberRole.coOrganizer));

    // Assert
    expect(find.text('Zona bahaya'), findsNothing);
    expect(find.text('Serahkan pengurus'), findsNothing);
  });
}
