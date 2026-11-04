import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/draw/domain/usecases/describe_draw_result_usecase.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';

import '../../fixtures.dart';

void main() {
  const useCase = DescribeDrawResultUseCase();
  const group = GroupDetail(
    id: 'g1',
    name: 'Arisan RT 05',
    amount: 200000,
    totalSlots: 10,
    myRole: MemberRole.organizer,
    myMemberId: 'm1',
  );
  final members = [Member(id: 'm5', slotId: goldenSlotId(5), slotNo: 5)];

  test('describes the winner, the pot and the organizer hand-over', () {
    // Act
    final view = useCase((draw: drawnDraw, group: group, period: const Period(id: 'p1'), members: members));

    // Assert
    expect(view.winnerName, 'Agus');
    expect(view.slotNo, 5);
    expect(view.periodNo, 4);
    expect(view.totalPeriods, 10);
    expect(view.potAmount, 2000000);
    expect(view.isMine, isFalse);
    expect(view.showHandOver, isTrue);
  });

  test('the winner sees it as their own', () {
    // Act
    final view = useCase((
      draw: drawnDraw,
      group: group.copyWith(myRole: MemberRole.member, myMemberId: 'm5'),
      period: null,
      members: members,
    ));

    // Assert
    expect(view.isMine, isTrue);
    expect(view.showHandOver, isFalse);
  });

  test('no hand-over card once the payout is recorded', () {
    // Act
    final view = useCase((
      draw: drawnDraw,
      group: group,
      period: const Period(id: 'p1', payoutRecorded: true),
      members: members,
    ));

    // Assert
    expect(view.showHandOver, isFalse);
  });
}
