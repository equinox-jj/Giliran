import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/utils/clock.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/data/repositories/group_repository_impl.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/data/repositories/member_repository_impl.dart';
import 'package:giliran/features/member/domain/entities/leave_request.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/entities/obligation.dart';
import 'package:giliran/features/member/presentation/leave_requests/page/leave_requests_page.dart';
import 'package:giliran/features/member/presentation/shared/widgets/leave_request_sheet.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

GroupDetail _group(MemberRole role) => GroupDetail(
  id: 'g1',
  name: 'Arisan RT 05',
  totalSlots: 10,
  status: GroupStatus.active,
  myRole: role,
  myMemberId: 'm3',
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakeMemberRepository members;
  late List<String> events;

  setUp(() {
    groups = FakeGroupRepository();
    members = FakeMemberRepository();
    events = [];
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        memberRepositoryProvider.overrideWithValue(members),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(page, container: container);
    await tester.pumpAndSettle();
  }

  group('LeaveRequestSheet', () {
    testWidgets('a member sends the request with a reason', (tester) async {
      // Arrange
      await pump(
        tester,
        Scaffold(
          body: LeaveRequestSheet(group: _group(MemberRole.member), onTransfer: () {}),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Pindah kota');

      // Act
      await tester.tap(find.text('Kirim permintaan'));
      await tester.pumpAndSettle();

      // Assert
      expect(members.calls, contains('requestLeave'));
      expect(members.lastReason, 'Pindah kota');
    });

    testWidgets('the organizer is pointed to the ownership transfer', (tester) async {
      // Arrange
      await pump(
        tester,
        Scaffold(
          body: LeaveRequestSheet(group: _group(MemberRole.organizer), onTransfer: () => events.add('transfer')),
        ),
      );

      // Act
      await tester.tap(find.text('Serahkan pengurus'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Kirim permintaan'), findsNothing);
      expect(events, ['transfer']);
    });

    testWidgets('organizer_cannot_leave from the server shows the same state', (tester) async {
      // Arrange
      members.leaveResult = Left(conflict(ApiErrorCode.organizerCannotLeave));
      await pump(
        tester,
        Scaffold(
          body: LeaveRequestSheet(group: _group(MemberRole.coOrganizer), onTransfer: () {}),
        ),
      );

      // Act
      await tester.tap(find.text('Kirim permintaan'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Serahkan pengurus'), findsOneWidget);
    });

    testWidgets('a past winner who still owes sees the meter instead of the form', (tester) async {
      // Act
      await pump(
        tester,
        Scaffold(
          body: LeaveRequestSheet(
            group: _group(MemberRole.member),
            obligation: const Obligation(
              member: MemberRef(id: 'm3', displayName: 'Bu Sri'),
              wonPeriodNo: 3,
              remainingCount: 7,
              remainingAmount: 1400000,
            ),
            onTransfer: () {},
          ),
        ),
      );

      // Assert
      expect(find.byType(ObligationMeter), findsOneWidget);
      expect(find.text('Kamu sudah menang dan masih punya 7 iuran. Lunasi dulu sebelum keluar.'), findsOneWidget);
      expect(find.text('Kirim permintaan'), findsNothing);
    });
  });

  group('LeaveRequestsPage', () {
    setUp(() {
      groups.group = _group(MemberRole.organizer);
      members.leaveRequests = [
        LeaveRequest(
          id: 'r1',
          member: const MemberRef(id: 'm5', displayName: 'Pak Dedi', slotNo: 5),
          reason: 'Pindah kota',
          createdAt: DateTime.utc(2026, 11, 3, 3),
        ),
      ];
    });

    testWidgets('approving removes the card', (tester) async {
      // Arrange
      await pump(tester, const LeaveRequestsPage(groupId: 'g1'));

      // Act
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();

      // Assert
      expect(members.calls, contains('approveLeave:r1'));
      expect(find.text('Tidak ada permintaan keluar.'), findsOneWidget);
    });

    testWidgets('rejecting asks for a reason first', (tester) async {
      // Arrange
      await pump(tester, const LeaveRequestsPage(groupId: 'g1'));
      await tester.tap(find.text('Tolak'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Masih ada iuran');

      // Act
      await tester.tap(find.text('Tolak permintaan'));
      await tester.pumpAndSettle();

      // Assert
      expect(members.calls, contains('rejectLeave:r1'));
      expect(members.lastReason, 'Masih ada iuran');
    });

    testWidgets('a past winner shows the obligation warning', (tester) async {
      // Arrange
      members.obligations = const [
        Obligation(member: MemberRef(id: 'm5'), wonPeriodNo: 2, remainingCount: 8, remainingAmount: 1600000),
      ];

      // Act
      await pump(tester, const LeaveRequestsPage(groupId: 'g1'));

      // Assert
      expect(find.text('Sudah menang. Pastikan sisa iurannya beres sebelum disetujui.'), findsOneWidget);
      expect(find.byType(ObligationMeter), findsOneWidget);
    });
  });
}
