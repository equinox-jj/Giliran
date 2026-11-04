import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/period_status.dart';
import '../../../payment/domain/entities/period.dart';
import '../entities/schedule.dart';

part 'build_schedule_usecase.g.dart';

/// Lays a cycle's periods out for the Jadwal timeline (S21, Tikar §9.5).
///
/// A period runs from the previous period's draw date to its own; the first
/// one starts one period length (P1 to P2) before its draw. [ScheduleScale.period]
/// gives each period an equal column, [ScheduleScale.month] places bars on
/// real dates. Completion is the share of drawn or closed periods. Pure and
/// synchronous, so it does not go through `UseCase`.
class const BuildScheduleUseCase() {
  static const _fallbackPeriod = Duration(days: 30);

  Schedule call(({List<Period> periods, DateTime today, ScheduleScale scale}) params) {
    final periods = [...params.periods]..sort((a, b) => (a.periodNo ?? 0).compareTo(b.periodNo ?? 0));
    if (periods.isEmpty) return const Schedule(bars: [], todayAt: null, completionPercent: 0);

    final drawn = periods.where((p) => p.isDrawn).length;
    final completion = (drawn * 100 / periods.length).round();
    final spans = _spans(periods);
    final today = params.today;

    if (params.scale == ScheduleScale.period || spans == null) {
      final n = periods.length;
      return Schedule(
        bars: [for (var i = 0; i < n; i++) _bar(periods[i], i / n, (i + 1) / n)],
        todayAt: spans == null ? null : _todayInColumns(spans, today),
        completionPercent: completion,
      );
    }

    final rangeStart = spans.first.start;
    final rangeEnd = spans.last.end;
    final total = rangeEnd.difference(rangeStart).inMinutes;
    double at(DateTime d) => total <= 0 ? 0 : (d.difference(rangeStart).inMinutes / total).clamp(0.0, 1.0);

    return Schedule(
      bars: [for (var i = 0; i < periods.length; i++) _bar(periods[i], at(spans[i].start), at(spans[i].end))],
      todayAt: at(today),
      completionPercent: completion,
      ticks: [
        for (
          var m = DateTime.utc(rangeStart.year, rangeStart.month + 1);
          !m.isAfter(rangeEnd);
          m = DateTime.utc(m.year, m.month + 1)
        )
          ScheduleTick(at: at(m), month: m),
      ],
    );
  }

  /// Each period's start and end, or null when a draw date is missing.
  static List<({DateTime start, DateTime end})>? _spans(List<Period> periods) {
    if (periods.any((p) => p.drawDate == null)) return null;
    final draws = [for (final p in periods) p.drawDate!];
    final firstLength = draws.length > 1 ? draws[1].difference(draws[0]) : _fallbackPeriod;
    return [
      for (var i = 0; i < draws.length; i++)
        (start: i == 0 ? draws[0].subtract(firstLength) : draws[i - 1], end: draws[i]),
    ];
  }

  static double _todayInColumns(List<({DateTime start, DateTime end})> spans, DateTime today) {
    final n = spans.length;
    if (today.isBefore(spans.first.start)) return 0;
    for (var i = 0; i < n; i++) {
      final s = spans[i];
      if (!today.isAfter(s.end)) {
        final length = s.end.difference(s.start).inMinutes;
        final into = length <= 0 ? 1.0 : today.difference(s.start).inMinutes / length;
        return (i + into.clamp(0.0, 1.0)) / n;
      }
    }
    return 1;
  }

  static ScheduleBar _bar(Period p, double start, double end) => ScheduleBar(
    period: p,
    periodId: p.id ?? 'p${p.periodNo}',
    periodNo: p.periodNo ?? 0,
    state: switch (p.status) {
      PeriodStatus.drawn || PeriodStatus.closed => ScheduleBarState.drawn,
      PeriodStatus.open => ScheduleBarState.open,
      PeriodStatus.upcoming || null => ScheduleBarState.upcoming,
    },
    start: start,
    end: end,
    winnerId: p.winner?.id,
    winnerName: p.winner?.displayName,
  );
}

@Riverpod(keepAlive: true)
BuildScheduleUseCase buildScheduleUseCase(Ref ref) => const BuildScheduleUseCase();
