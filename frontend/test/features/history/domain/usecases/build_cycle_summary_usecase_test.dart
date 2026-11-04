import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/group_status.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/group/domain/entities/group.dart';
import 'package:giliran/features/history/domain/usecases/build_cycle_summary_usecase.dart';
import 'package:giliran/features/member/domain/entities/member.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';

Period _period(int n, {required bool drawn, int paid = 10, int total = 10}) => Period(
  id: 'p$n',
  periodNo: n,
  status: drawn ? PeriodStatus.closed : PeriodStatus.upcoming,
  drawnAt: drawn ? DateTime.utc(2026, n, 5, 12) : null,
  winner: drawn ? MemberRef(id: 'm$n', displayName: 'Pemenang $n') : null,
  paymentSummary: drawn ? PaymentSummary(paidCount: paid, totalCount: total, collectedAmount: paid * 200000) : null,
);

void main() {
  const build = BuildCycleSummaryUseCase();

  test('a completed cycle counts periods, winners, money and members', () {
    // Arrange
    final group = GroupDetail(
      id: 'g1',
      status: GroupStatus.completed,
      totalSlots: 10,
      amount: 200000,
      completedAt: DateTime.utc(2026, 10, 6),
    );
    final periods = [
      for (var n = 1; n <= 10; n++) _period(n, drawn: true, paid: n == 3 ? 8 : 10),
    ];

    // Act
    final s = build((group: group, periods: periods));

    // Assert
    expect(s.periodCount, 10);
    expect(s.winnerCount, 10);
    expect(s.totalCollected, 98 * 200000);
    expect(s.paidPercent, 98);
    expect(s.memberCount, 10);
    expect(s.closedEarly, isFalse);
    expect(s.endedAt, DateTime.utc(2026, 10, 6));
    expect(s.winners.map((w) => w.periodNo), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(s.undrawnPeriodNos, isEmpty);
  });

  test('a group closed early lists its undrawn periods', () {
    // Arrange
    final group = GroupDetail(
      id: 'g1',
      status: GroupStatus.closed,
      totalSlots: 5,
      closedAt: DateTime.utc(2026, 3, 20),
    );
    final periods = [for (var n = 1; n <= 5; n++) _period(n, drawn: n <= 2)];

    // Act
    final s = build((group: group, periods: periods));

    // Assert
    expect(s.closedEarly, isTrue);
    expect(s.endedAt, DateTime.utc(2026, 3, 20));
    expect(s.winnerCount, 2);
    expect(s.undrawnPeriodNos, [3, 4, 5]);
  });

  test('winners come in period order whatever the input order', () {
    // Arrange
    const group = GroupDetail(id: 'g1', status: GroupStatus.completed, totalSlots: 3);
    final periods = [_period(3, drawn: true), _period(1, drawn: true), _period(2, drawn: true)];

    // Act
    final s = build((group: group, periods: periods));

    // Assert
    expect(s.winners.map((w) => w.winner?.displayName), ['Pemenang 1', 'Pemenang 2', 'Pemenang 3']);
  });

  test('without payment summaries the paid rate is unknown', () {
    // Arrange
    const group = GroupDetail(id: 'g1', status: GroupStatus.completed, totalSlots: 2);
    const periods = [Period(id: 'p1', periodNo: 1, status: PeriodStatus.closed)];

    // Act
    final s = build((group: group, periods: periods));

    // Assert
    expect(s.paidPercent, isNull);
    expect(s.totalCollected, 0);
  });
}
