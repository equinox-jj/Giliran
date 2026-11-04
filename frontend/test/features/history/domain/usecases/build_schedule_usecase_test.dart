import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/history/domain/entities/schedule.dart';
import 'package:giliran/features/history/domain/usecases/build_schedule_usecase.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';

/// Ten monthly periods drawn on the 5th, P1–P4 drawn, P5 open.
List<Period> _periods() => [
  for (var n = 1; n <= 10; n++)
    Period(
      id: 'p$n',
      periodNo: n,
      drawDate: DateTime.utc(2026, n, 5),
      dueDate: DateTime.utc(2026, n, 5),
      status: n <= 4
          ? PeriodStatus.drawn
          : n == 5
          ? PeriodStatus.open
          : PeriodStatus.upcoming,
      winner: n <= 4 ? MemberRef(id: 'm$n', displayName: 'Pemenang $n') : null,
    ),
];

void main() {
  const useCase = BuildScheduleUseCase();

  test('cycle completion is the share of drawn periods', () {
    // Arrange
    final periods = _periods();

    // Act
    final schedule = useCase((periods: periods, today: DateTime.utc(2026, 5, 1), scale: ScheduleScale.period));

    // Assert
    expect(schedule.completionPercent, 40);
  });

  test('bars come sorted by period with their state and winner', () {
    // Arrange
    final periods = _periods().reversed.toList();

    // Act
    final schedule = useCase((periods: periods, today: DateTime.utc(2026, 5, 1), scale: ScheduleScale.period));

    // Assert
    expect(schedule.bars.map((b) => b.periodNo), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(schedule.bars[3].state, ScheduleBarState.drawn);
    expect(schedule.bars[3].winnerName, 'Pemenang 4');
    expect(schedule.bars[4].state, ScheduleBarState.open);
    expect(schedule.bars[5].state, ScheduleBarState.upcoming);
  });

  test('period scale gives each period an equal column', () {
    // Arrange
    final periods = _periods();

    // Act
    final schedule = useCase((periods: periods, today: DateTime.utc(2026, 5, 1), scale: ScheduleScale.period));

    // Assert
    expect(schedule.bars[0].start, 0);
    expect(schedule.bars[0].end, closeTo(0.1, 1e-9));
    expect(schedule.bars[9].end, closeTo(1, 1e-9));
    expect(schedule.ticks, isEmpty);
  });

  test('period scale puts today inside the period that runs then', () {
    // Arrange
    final periods = _periods();
    // P5 runs from Apr 5 (P4's draw) to May 5; Apr 20 is half way.
    final today = DateTime.utc(2026, 4, 20);

    // Act
    final schedule = useCase((periods: periods, today: today, scale: ScheduleScale.period));

    // Assert
    expect(schedule.todayAt, closeTo(0.4 + 0.1 * 15 / 30, 1e-9));
  });

  test('month scale places bars and today on real dates', () {
    // Arrange
    final periods = _periods();

    // Act
    final schedule = useCase((periods: periods, today: DateTime.utc(2026, 5, 5), scale: ScheduleScale.month));

    // Assert
    // P1 starts one period (31 days, P1→P2) before its draw: Dec 5 2025.
    final start = DateTime.utc(2025, 12, 5);
    final rangeDays = DateTime.utc(2026, 10, 5).difference(start).inDays;
    expect(schedule.bars[0].start, 0);
    expect(schedule.bars[9].end, closeTo(1, 1e-9));
    expect(schedule.todayAt, closeTo(DateTime.utc(2026, 5, 5).difference(start).inDays / rangeDays, 1e-9));
    expect(schedule.ticks.first.month, DateTime.utc(2026));
    expect(schedule.ticks.length, 10);
  });

  test('today outside the cycle is clamped to its ends', () {
    // Arrange
    final periods = _periods();

    // Act
    final before = useCase((periods: periods, today: DateTime.utc(2025, 1, 1), scale: ScheduleScale.period));
    final after = useCase((periods: periods, today: DateTime.utc(2027, 1, 1), scale: ScheduleScale.month));

    // Assert
    expect(before.todayAt, 0);
    expect(after.todayAt, 1);
  });

  test('no periods gives an empty schedule', () {
    // Act
    final schedule = useCase((periods: const [], today: DateTime.utc(2026), scale: ScheduleScale.period));

    // Assert
    expect(schedule.bars, isEmpty);
    expect(schedule.completionPercent, 0);
    expect(schedule.todayAt, isNull);
  });
}
