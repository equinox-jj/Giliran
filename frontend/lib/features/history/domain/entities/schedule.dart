import '../../../payment/domain/entities/period.dart';

/// The axis the Jadwal timeline lays periods on: equal columns per
/// period, or real dates on a month axis.
enum ScheduleScale() {
  period,
  month,
}

/// Where a period stands, as its timeline bar shows it.
enum ScheduleBarState() {
  drawn,
  open,
  upcoming,
}

/// One period's bar on the Jadwal timeline, with the [period] it stands
/// for so the list under the timeline can show its dates. [start] and [end] are positions
/// along the axis, from 0 (cycle start) to 1 (last draw).
class const ScheduleBar({
  required final Period period,
  required final String periodId,
  required final int periodNo,
  required final ScheduleBarState state,
  required final double start,
  required final double end,
  final String? winnerId,
  final String? winnerName,
});

/// A month boundary on the month axis, at [at] along it.
class const ScheduleTick({required final double at, required final DateTime month});

/// The Jadwal timeline of a cycle: one bar per period, where today falls
/// (null without periods) and how much of the cycle is drawn.
class const Schedule({
  required final List<ScheduleBar> bars,
  required final double? todayAt,
  required final int completionPercent,
  final List<ScheduleTick> ticks = const [],
});
