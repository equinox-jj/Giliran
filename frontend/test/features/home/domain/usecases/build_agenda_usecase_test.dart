import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/features/home/domain/entities/agenda_day.dart';
import 'package:giliran/features/home/domain/usecases/build_agenda_usecase.dart';

import '../../../../helpers/group_fixtures.dart';

void main() {
  // 23.30 WIB on Wed 4 Nov 2026 is still the 4th in Jakarta.
  final now = DateTime.utc(2026, 11, 4, 16, 30);

  test('seven days with today third', () {
    // Act
    final days = const BuildAgendaUseCase()((groups: const [], now: now));

    // Assert
    expect(days, hasLength(7));
    expect(days.first.date, DateTime.utc(2026, 11, 2));
    expect(days[2].isToday, isTrue);
    expect(days[2].date, DateTime.utc(2026, 11, 4));
    expect(days.where((d) => d.isToday), hasLength(1));
  });

  test('a due date outranks a draw on the same day', () {
    // Arrange
    final groups = [
      summary('a', draw: DateTime.utc(2026, 11, 6), due: DateTime.utc(2026, 11, 20)),
      summary('b', payment: PaymentStatus.unpaid, due: DateTime.utc(2026, 11, 6), draw: DateTime.utc(2026, 11, 30)),
    ];

    // Act
    final days = const BuildAgendaUseCase()((groups: groups, now: now));

    // Assert
    final day = days.firstWhere((d) => d.date == DateTime.utc(2026, 11, 6));
    expect(day.topKind, AgendaEventKind.due);
    expect(day.events.map((e) => e.groupId), ['b', 'a']);
  });

  test('days without events are empty', () {
    // Arrange
    final groups = [summary('a', due: DateTime.utc(2026, 11, 5))];

    // Act
    final days = const BuildAgendaUseCase()((groups: groups, now: now));

    // Assert
    expect(days.where((d) => d.topKind == null), hasLength(6));
  });
}
