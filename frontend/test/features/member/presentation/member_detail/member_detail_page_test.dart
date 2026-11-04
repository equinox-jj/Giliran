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
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/member/domain/entities/obligation.dart';
import 'package:giliran/features/member/presentation/member_detail/page/member_detail_page.dart';
import 'package:giliran/shared/widgets/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/failures.dart';
import '../../../../helpers/fake_group_repository.dart';
import '../../../../helpers/fake_member_repository.dart';
import '../../../../helpers/pump_app.dart';

const _dedi = Member(
  id: 'm2',
  groupId: 'g1',
  displayName: 'Pak Dedi',
  slotNo: 2,
  role: MemberRole.member,
  hasWon: true,
  wonPeriodNo: 3,
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late FakeGroupRepository groups;
  late FakeMemberRepository members;
  late List<String> events;

  setUp(() {
    groups = FakeGroupRepository()
      ..group = const GroupDetail(
        id: 'g1',
        name: 'Arisan RT 05',
        totalSlots: 10,
        status: GroupStatus.active,
        myRole: MemberRole.organizer,
        myMemberId: 'm1',
      );
    members = FakeMemberRepository()
      ..member = _dedi
      ..memberResult = const Right(_dedi)
      ..obligations = const [
        Obligation(member: MemberRef(id: 'm2'), wonPeriodNo: 3, remainingCount: 7, remainingAmount: 1400000),
      ];
    events = [];
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        memberRepositoryProvider.overrideWithValue(members),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4, 3)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpPage(
      MemberDetailPage(groupId: 'g1', memberId: 'm2', onRemoved: () => events.add('removed')),
      container: container,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the obligation meter for a past winner', (tester) async {
    // Act
    await pumpDetail(tester);

    // Assert
    expect(find.byType(ObligationMeter), findsOneWidget);
    expect(find.text('Periode 3'), findsOneWidget);
  });

  testWidgets('removal blocked by obligations explains how many dues are left', (tester) async {
    // Arrange
    members.removeResult = Left(conflict(ApiErrorCode.obligationsOutstanding));
    await pumpDetail(tester);
    await tester.scrollUntilVisible(find.text('Keluarkan dari grup'), 200);
    await tester.tap(find.text('Keluarkan dari grup'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('Keluarkan dari grup').last);
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Pak Dedi sudah menang dan masih punya 7 iuran.'), findsOneWidget);
    expect(events, isEmpty);
  });

  testWidgets('a confirmed removal reports back', (tester) async {
    // Arrange
    await pumpDetail(tester);
    await tester.scrollUntilVisible(find.text('Keluarkan dari grup'), 200);
    await tester.tap(find.text('Keluarkan dari grup'));
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('Keluarkan dari grup').last);
    await tester.pumpAndSettle();

    // Assert
    expect(members.calls, contains('removeMember:m2'));
    expect(events, ['removed']);
  });
}
