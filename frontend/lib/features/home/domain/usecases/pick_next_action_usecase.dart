import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/enums/group_status.dart';
import '../../../../core/utils/enums/payment_status.dart';
import '../../../group/domain/entities/group_summary.dart';
import '../entities/next_action.dart';

part 'pick_next_action_usecase.g.dart';

/// Input for [PickNextActionUseCase]. [payoutsToConfirm] holds the ids of
/// groups where I won and must confirm the payout; `GroupSummary` does not
/// carry that yet, so it stays empty until the payout feature fills it.
typedef NextActionParams = ({
  List<GroupSummary> groups,
  DateTime now,
  Set<String> payoutsToConfirm,
});

/// Picks the Home hero's item by priority: my payment rejected → my
/// payment due within 3 days → proofs to review (manager) → draw today
/// (manager) → payout to confirm (winner). Within one kind the soonest due
/// date wins. Null when nothing is urgent.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const PickNextActionUseCase() {
  static const dueSoonDays = 3;

  NextAction? call(NextActionParams params) {
    final today = AppDate.jakartaToday(params.now);
    final active = params.groups.where((g) => g.status == GroupStatus.active).toList()..sort(_byDueDate);

    for (final g in active) {
      if (g.myPaymentStatus == PaymentStatus.rejected) {
        return NextAction(kind: NextActionKind.paymentRejected, group: g);
      }
    }
    for (final g in active) {
      final due = g.nextDueDate;
      if (g.myPaymentStatus == PaymentStatus.unpaid && due != null && due.difference(today).inDays <= dueSoonDays) {
        return NextAction(kind: NextActionKind.paymentDue, group: g);
      }
    }
    for (final g in active) {
      final pending = g.pendingReviewCount ?? 0;
      if (g.isManager && pending > 0) {
        return NextAction(kind: NextActionKind.reviewProofs, group: g, count: pending);
      }
    }
    for (final g in active) {
      if (g.isManager && g.nextDrawDate == today) {
        return NextAction(kind: NextActionKind.drawToday, group: g);
      }
    }
    for (final g in params.groups) {
      if (params.payoutsToConfirm.contains(g.id)) {
        return NextAction(kind: NextActionKind.confirmPayout, group: g);
      }
    }
    return null;
  }

  static int _byDueDate(GroupSummary a, GroupSummary b) {
    final da = a.nextDueDate;
    final db = b.nextDueDate;
    if (da == null) return db == null ? 0 : 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
}

@Riverpod(keepAlive: true)
PickNextActionUseCase pickNextActionUseCase(Ref ref) => const PickNextActionUseCase();
