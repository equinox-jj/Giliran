import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/member_role.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/payout.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/features/payment/domain/usecases/pick_payout_stage_usecase.dart';

void main() {
  const useCase = PickPayoutStageUseCase();
  const organizer = GroupDetail(id: 'g1', myRole: MemberRole.organizer, myMemberId: 'm1');
  const winner = GroupDetail(id: 'g1', myRole: MemberRole.member, myMemberId: 'm5');
  const member = GroupDetail(id: 'g1', myRole: MemberRole.member, myMemberId: 'm2');
  const period = Period(
    id: 'p1',
    winner: MemberRef(id: 'm5', displayName: 'Bu Rina'),
  );
  final recorded = Payout(
    id: 'po1',
    winner: const MemberRef(id: 'm5'),
    recordedAt: DateTime.utc(2026, 10, 26),
  );

  final cases = <String, (GroupDetail, Payout?, PayoutStage)>{
    'organizer before recording': (organizer, null, PayoutStage.record),
    'member before recording': (member, null, PayoutStage.notRecorded),
    'winner before recording': (winner, null, PayoutStage.notRecorded),
    'organizer after recording': (organizer, recorded, PayoutStage.waiting),
    'winner after recording': (winner, recorded, PayoutStage.confirm),
    'anyone after confirming': (
      member,
      recorded.copyWith(confirmedAt: DateTime.utc(2026, 10, 27)),
      PayoutStage.confirmed,
    ),
  };

  for (final MapEntry(key: name, value: (group, payout, stage)) in cases.entries) {
    test('$name shows ${stage.name}', () {
      // Act
      final result = useCase((group: group, period: period, payout: payout));

      // Assert
      expect(result, stage);
    });
  }
}
