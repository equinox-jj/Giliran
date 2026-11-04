import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/draw_method.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/core/utils/enums/member_status.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/draw/domain/usecases/plan_draw_stage_usecase.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';

void main() {
  const useCase = PlanDrawStageUseCase();
  final drawDate = DateTime.utc(2026, 10, 26);
  final period = Period(id: 'p1', periodNo: 4, status: PeriodStatus.open, drawDate: drawDate);
  const organizer = GroupDetail(id: 'g1', myRole: MemberRole.organizer, drawMethod: DrawMethod.random);
  final members = [
    const Member(id: 'm3', slotNo: 3, displayName: 'C', fixedOrderPosition: 1),
    const Member(id: 'm1', slotNo: 1, displayName: 'A', hasWon: true, fixedOrderPosition: 2),
    const Member(id: 'm2', slotNo: 2, displayName: 'B', fixedOrderPosition: 3),
    const Member(id: 'm4', slotNo: 4, displayName: 'D', status: MemberStatus.left),
  ];
  // 19.30 Jakarta on the draw date.
  final onDrawDay = DateTime.utc(2026, 10, 26, 12, 30);

  DrawStagePlan plan({GroupDetail group = organizer, Period? p, bool online = true, DateTime? now}) =>
      useCase((group: group, period: p ?? period, members: members, online: online, now: now ?? onDrawDay));

  test('eligible slots are the unwon active members by slot number', () {
    // Act
    final result = plan();

    // Assert
    expect(result.eligible.map((m) => m.id), ['m2', 'm3']);
    expect(result.canRun, isTrue);
  });

  test('before the draw date the button waits with the date', () {
    // Act
    final result = plan(now: DateTime.utc(2026, 10, 25, 12));

    // Assert
    expect(result.blocker, DrawBlocker.tooEarly);
    expect(result.availableOn, drawDate);
  });

  test('just after Jakarta midnight on the draw date it is ready', () {
    // Act: 00.30 WIB on Oct 26 is still Oct 25 in UTC.
    final result = plan(now: DateTime.utc(2026, 10, 25, 17, 30));

    // Assert
    expect(result.blocker, isNull);
  });

  test('members watch', () {
    // Act
    final result = plan(group: organizer.copyWith(myRole: MemberRole.member));

    // Assert
    expect(result.manager, isFalse);
    expect(result.blocker, DrawBlocker.notManager);
  });

  test('offline blocks the draw', () {
    // Act
    final result = plan(online: false);

    // Assert
    expect(result.blocker, DrawBlocker.offline);
  });

  test('a period that is not open blocks the draw', () {
    // Act
    final result = plan(p: period.copyWith(status: PeriodStatus.upcoming));

    // Assert
    expect(result.blocker, DrawBlocker.notOpen);
  });

  test('fixed order picks the lowest unwon position', () {
    // Act
    final result = plan(group: organizer.copyWith(drawMethod: DrawMethod.fixedOrder));

    // Assert
    expect(result.fixedOrder, isTrue);
    expect(result.nextInOrder?.id, 'm3');
  });
}
