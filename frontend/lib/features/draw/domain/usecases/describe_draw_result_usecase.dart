import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../group/domain/entities/group.dart';
import '../../../member/domain/entities/member.dart';
import '../../../payment/domain/entities/period.dart';
import '../entities/draw.dart';

part 'describe_draw_result_usecase.freezed.dart';
part 'describe_draw_result_usecase.g.dart';

typedef DrawResultInput = ({Draw draw, GroupDetail? group, Period? period, List<Member> members});

/// What the result screen (S38) says about a finished draw.
@freezed
abstract class DrawResultView with _$DrawResultView {
  const factory({
    required String groupName,
    required int periodNo,
    required int totalPeriods,
    required String winnerName,
    required int slotNo,

    /// The viewer is the winner: "Selamat, **kamu** dapat giliran!".
    required bool isMine,

    /// The pot (amount × slots) handed to the winner.
    required int potAmount,

    /// Organizers see "Serahkan {pot} ke {winner}" until the payout is
    /// recorded.
    required bool showHandOver,
  }) = _DrawResultView;
}

/// Combines the draw with the cached group, period and members into a
/// [DrawResultView].
class const DescribeDrawResultUseCase() {
  DrawResultView call(DrawResultInput input) {
    final (:draw, :group, :period, :members) = input;
    final winner = draw.winner;
    final winnerMemberId =
        period?.winner?.id ?? members.where((m) => m.slotId != null && m.slotId == winner?.slotId).firstOrNull?.id;
    final myId = group?.myMemberId;
    final slots = group?.totalSlots ?? 0;
    return DrawResultView(
      groupName: group?.name ?? '',
      periodNo: draw.periodNo ?? period?.periodNo ?? 0,
      totalPeriods: slots,
      winnerName: winner?.displayName ?? period?.winner?.displayName ?? '',
      slotNo: winner?.slotNo ?? period?.winner?.slotNo ?? 0,
      isMine: myId != null && winnerMemberId == myId,
      potAmount: group?.potAmount ?? (group?.amount ?? 0) * slots,
      showHandOver: (group?.isManager ?? false) && period?.payoutRecorded != true,
    );
  }
}

@Riverpod(keepAlive: true)
DescribeDrawResultUseCase describeDrawResultUseCase(Ref ref) => const DescribeDrawResultUseCase();
