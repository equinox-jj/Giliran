import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/group_status.dart';
import '../../../group/domain/entities/group.dart';
import '../../../payment/domain/entities/period.dart';
import '../entities/cycle_summary.dart';

part 'build_cycle_summary_usecase.g.dart';

/// Sums up a finished cycle for the Cycle Summary card (S24): periods and
/// winners, money collected, the share of dues paid, the members, and for
/// a group closed early the periods it never drew. Works from the cached
/// group and periods only (no extra API). Pure and synchronous, so it does
/// not go through `UseCase`.
class const BuildCycleSummaryUseCase() {
  CycleSummary call(({GroupDetail group, List<Period> periods}) params) {
    final group = params.group;
    final periods = [...params.periods]..sort((a, b) => (a.periodNo ?? 0).compareTo(b.periodNo ?? 0));
    var collected = 0;
    var paid = 0;
    var due = 0;
    for (final p in periods) {
      final s = p.paymentSummary;
      if (s == null) continue;
      collected += s.collectedAmount ?? 0;
      paid += s.paidCount ?? 0;
      due += s.totalCount ?? 0;
    }
    final winners = [
      for (final p in periods)
        if (p.isDrawn && p.id != null)
          CycleWinner(periodId: p.id!, periodNo: p.periodNo ?? 0, winner: p.winner, drawnAt: p.drawnAt),
    ];
    final closedEarly = group.status == GroupStatus.closed;
    return CycleSummary(
      periodCount: group.totalSlots ?? periods.length,
      winnerCount: winners.where((w) => w.winner != null).length,
      totalCollected: collected,
      paidPercent: due == 0 ? null : (paid * 100 / due).round(),
      memberCount: group.totalSlots ?? 0,
      closedEarly: closedEarly,
      endedAt: group.completedAt ?? group.closedAt,
      winners: winners,
      undrawnPeriodNos: closedEarly
          ? [
              for (final p in periods)
                if (!p.isDrawn) p.periodNo ?? 0,
            ]
          : const [],
    );
  }
}

@Riverpod(keepAlive: true)
BuildCycleSummaryUseCase buildCycleSummaryUseCase(Ref ref) => const BuildCycleSummaryUseCase();
