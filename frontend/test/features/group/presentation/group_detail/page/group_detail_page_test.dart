import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/core/utils/enums/period_type.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/group/presentation/group_detail/page/group_detail_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/fake_group_repository.dart';
import '../../../../../helpers/pump_app.dart';

const _active = GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  amount: 200000,
  potAmount: 2000000,
  periodType: PeriodType.monthly,
  totalSlots: 10,
  filledSlots: 10,
  status: GroupStatus.active,
  myRole: MemberRole.member,
  currentPeriodNo: 4,
  paidCount: 8,
  myPaymentStatus: PaymentStatus.paid,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late List<String> opened;

  setUp(() {
    groups = FakeGroupRepository();
    opened = [];
  });

  Future<void> pumpDetail(WidgetTester tester, GroupDetail group, {bool created = false}) async {
    groups
      ..group = group
      ..groupResult = null;
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      GroupDetailPage(
        groupId: 'g1',
        created: created,
        onEdit: () => opened.add('edit'),
        onPaymentInfo: () => opened.add('paymentInfo'),
        onInvite: () => opened.add('invite'),
        onStart: () => opened.add('start'),
        onOpenMember: (mid) => opened.add('member:$mid'),
        onLeaveRequests: () => opened.add('leaveRequests'),
        onTransfer: () => opened.add('transfer'),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(OverflowMenuButton));
    await tester.pumpAndSettle();
  }

  testWidgets('an active group says who paid this period', (tester) async {
    // Act
    await pumpDetail(tester, _active);

    // Assert
    expect(find.text('Periode 4 dari 10, 8 orang sudah bayar.'), findsOneWidget);
    expect(find.text('Tinggal tunggu kocokan'), findsOneWidget);
  });

  testWidgets('a draft group counts the filled slots', (tester) async {
    // Arrange
    final draft = _active.copyWith(status: GroupStatus.draft, filledSlots: 8, myRole: MemberRole.organizer);

    // Act
    await pumpDetail(tester, draft);

    // Assert
    expect(find.text('8 dari 10 slot terisi. Undang 2 lagi.'), findsOneWidget);
    expect(find.text('Lanjutkan persiapan'), findsOneWidget);
    expect(find.byType(PeriodStrip), findsNothing);
  });

  testWidgets('a completed group says it is finished', (tester) async {
    // Act
    await pumpDetail(tester, _active.copyWith(status: GroupStatus.completed));

    // Assert
    expect(find.text('Arisan selesai.'), findsOneWidget);
  });

  testWidgets('a member menu has Bagikan and Minta keluar', (tester) async {
    // Arrange
    await pumpDetail(tester, _active);

    // Act
    await openMenu(tester);

    // Assert
    expect(find.text('Bagikan'), findsOneWidget);
    expect(find.text('Minta keluar'), findsOneWidget);
    expect(find.text('Edit grup'), findsNothing);
    expect(find.text('Tutup grup'), findsNothing);
  });

  testWidgets('the organizer menu has the management items', (tester) async {
    // Arrange
    await pumpDetail(tester, _active.copyWith(myRole: MemberRole.organizer));

    // Act
    await openMenu(tester);

    // Assert
    for (final label in ['Edit grup', 'Info rekening', 'Undang', 'Pengingat', 'Tutup grup']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Minta keluar'), findsNothing);
  });

  testWidgets('Edit grup in the menu opens Edit group', (tester) async {
    // Arrange
    await pumpDetail(tester, _active.copyWith(myRole: MemberRole.organizer));
    await openMenu(tester);

    // Act
    await tester.tap(find.text('Edit grup'));
    await tester.pumpAndSettle();

    // Assert
    expect(opened, ['edit']);
  });

  testWidgets('the organizer sees the review action with the pending count', (tester) async {
    // Act
    await pumpDetail(tester, _active.copyWith(myRole: MemberRole.organizer, pendingReviewCount: 2));

    // Assert
    expect(find.widgetWithText(AppButton, 'Tinjau 2 bukti'), findsOneWidget);
  });

  testWidgets('a new group asks to invite members', (tester) async {
    // Act
    await pumpDetail(tester, _active.copyWith(status: GroupStatus.draft, myRole: MemberRole.organizer), created: true);

    // Assert
    expect(find.text('Grup jadi! Undang anggota sekarang?'), findsOneWidget);
  });
}
