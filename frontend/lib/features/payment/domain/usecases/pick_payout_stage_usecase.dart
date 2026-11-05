import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../group/domain/entities/group.dart';
import '../entities/payout.dart';
import '../entities/period.dart';

part 'pick_payout_stage_usecase.g.dart';

/// Which version of the payout screen the viewer sees.
enum PayoutStage() {
  /// Organizer, not recorded yet: the record form.
  record,

  /// Recorded, waiting for the winner: "Menunggu konfirmasi {winner}".
  waiting,

  /// The winner, recorded but not confirmed: "Sudah terima …?".
  confirm,

  /// The winner confirmed: "Diterima {winner} · {date}".
  confirmed,

  /// A member before anything was recorded.
  notRecorded,
}

typedef PayoutStageInput = ({GroupDetail? group, Period? period, Payout? payout});

/// Picks the [PayoutStage] from my role, whether I won the period, and the
/// payout's state.
class const PickPayoutStageUseCase() {
  PayoutStage call(PayoutStageInput input) {
    final (:group, :period, :payout) = input;
    final winnerId = payout?.winner?.id ?? period?.winner?.id;
    final mine = winnerId != null && winnerId == group?.myMemberId;
    final recorded = payout?.recordedAt != null || (period?.payoutRecorded ?? false);
    final confirmed = payout?.confirmedAt != null || (period?.payoutConfirmed ?? false);
    if (confirmed) return PayoutStage.confirmed;
    if (!recorded) return (group?.isManager ?? false) ? PayoutStage.record : PayoutStage.notRecorded;
    return mine ? PayoutStage.confirm : PayoutStage.waiting;
  }
}

@Riverpod(keepAlive: true)
PickPayoutStageUseCase pickPayoutStageUseCase(Ref ref) => const PickPayoutStageUseCase();
