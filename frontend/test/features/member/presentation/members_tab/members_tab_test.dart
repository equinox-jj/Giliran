import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/leave_request.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/entities/obligation.dart';
import 'package:giliran/features/member/presentation/members_tab/widgets/members_tab.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

GroupDetail _group(MemberRole role) => GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  totalSlots: 10,
  filledSlots: 3,
  status: GroupStatus.active,
  myRole: role,
  myMemberId: role == MemberRole.organizer ? 'm1' : 'm3',
);

const _members = [
  Member(id: 'm1', displayName: 'Rina Ayu', slotNo: 1, role: MemberRole.organizer),
  Member(id: 'm2', displayName: 'Pak Dedi', slotNo: 2, role: MemberRole.member, hasWon: true, wonPeriodNo: 3),
  Member(
    id: 'm3',
    displayName: 'Bu Sri',
    slotNo: 3,
    role: MemberRole.member,
    isGuest: true,
    guestPhone: '+6281234567890',
  ),
];

void main() {
  late FakeMemberRepository members;
  late List<String> opened;

  setUp(() {
    members = FakeMemberRepository()..members = _members;
    opened = [];
  });

  Future<void> pumpTab(WidgetTester tester, MemberRole role) async {
    final container = ProviderContainer(overrides: [memberRepositoryProvider.overrideWithValue(members)]);
    addTearDown(container.dispose);
    await tester.pumpPage(
      Scaffold(
        body: CustomScrollView(
          slivers: [
            MembersTab(
              group: _group(role),
              onInvite: () => opened.add('invite'),
              onOpenMember: (id) => opened.add('member:$id'),
              onLeaveRequests: () => opened.add('leaveRequests'),
              onLeave: () => opened.add('leave'),
            ),
          ],
        ),
      ),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hides the obligations section while nobody has won', (tester) async {
    // Act
    await pumpTab(tester, MemberRole.member);

    // Assert
    expect(find.text('Kewajiban setelah menang'), findsNothing);
    expect(find.byType(ObligationMeter), findsNothing);
  });

  testWidgets('shows a meter per past winner', (tester) async {
    // Arrange
    members.obligations = const [
      Obligation(
        member: MemberRef(id: 'm2', displayName: 'Pak Dedi'),
        wonPeriodNo: 3,
        remainingCount: 7,
        remainingAmount: 1400000,
        overdueCount: 1,
        overdueAmount: 200000,
      ),
    ];

    // Act
    await pumpTab(tester, MemberRole.organizer);

    // Assert
    expect(find.text('Kewajiban setelah menang'), findsOneWidget);
    expect(find.text('Sudah menang P3 · sisa 7 × Rp200.000', findRichText: true), findsOneWidget);
    expect(find.text('Terlambat 1 iuran · Rp200.000'), findsOneWidget);
  });

  testWidgets('shows Pengurus, Tamu and Kamu badges and the won chip', (tester) async {
    // Act
    await pumpTab(tester, MemberRole.member);

    // Assert
    expect(find.text('Pengurus'), findsOneWidget);
    expect(find.text('Tamu'), findsOneWidget);
    expect(find.text('Kamu'), findsOneWidget);
    expect(find.text('Sudah dapat P3'), findsOneWidget);
  });

  testWidgets('organizers get Undang and Tambah tamu', (tester) async {
    // Arrange
    await pumpTab(tester, MemberRole.organizer);

    // Act
    await tester.tap(find.text('Undang'));

    // Assert
    expect(find.text('Tambah tamu'), findsOneWidget);
    expect(opened, ['invite']);
  });

  testWidgets('members get neither organizer button', (tester) async {
    // Act
    await pumpTab(tester, MemberRole.member);

    // Assert
    expect(find.text('Undang'), findsNothing);
    expect(find.text('Tambah tamu'), findsNothing);
  });

  testWidgets('pending leave requests show a row for organizers', (tester) async {
    // Arrange
    members.leaveRequests = const [LeaveRequest(id: 'r1'), LeaveRequest(id: 'r2')];
    await pumpTab(tester, MemberRole.organizer);

    // Act
    await tester.tap(find.text('Permintaan keluar (2)'));

    // Assert
    expect(opened, ['leaveRequests']);
  });

  testWidgets('a member sees their own pending request as a banner', (tester) async {
    // Arrange
    members.leaveRequests = const [LeaveRequest(id: 'r1')];

    // Act
    await pumpTab(tester, MemberRole.member);

    // Assert
    expect(find.text('Permintaan keluar menunggu persetujuan'), findsOneWidget);
    expect(find.text('Batalkan'), findsNothing);
  });

  testWidgets('guest phones show to organizers only', (tester) async {
    // Act
    await pumpTab(tester, MemberRole.member);

    // Assert
    expect(find.textContaining('812-3456-7890'), findsNothing);
  });

  testWidgets('organizers see the guest phone', (tester) async {
    // Act
    await pumpTab(tester, MemberRole.organizer);

    // Assert
    expect(find.textContaining('812-3456-7890'), findsOneWidget);
  });

  testWidgets('tapping a member opens their detail', (tester) async {
    // Arrange
    await pumpTab(tester, MemberRole.member);

    // Act
    await tester.tap(find.text('Pak Dedi'));

    // Assert
    expect(opened, ['member:m2']);
  });
}
