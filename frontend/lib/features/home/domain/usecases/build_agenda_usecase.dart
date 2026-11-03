import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../group/domain/entities/group_summary.dart';
import '../entities/agenda_day.dart';

part 'build_agenda_usecase.g.dart';

/// Builds the 7-day Home agenda strip (Tikar §9.9) from each group's next
/// due and draw dates: two days back, today, four days ahead, so today sits
/// middle-left. Events on a day are ordered due > draw > payout.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const BuildAgendaUseCase() {
  static const daysBefore = 2;
  static const length = 7;

  List<AgendaDay> call(({List<GroupSummary> groups, DateTime now}) params) {
    final today = AppDate.jakartaToday(params.now);
    final start = today.subtract(const Duration(days: daysBefore));
    return [
      for (var i = 0; i < length; i++) _day(start.add(Duration(days: i)), today, params.groups),
    ];
  }

  AgendaDay _day(DateTime date, DateTime today, List<GroupSummary> groups) {
    final events = <AgendaEvent>[
      for (final g in groups)
        if (g.nextDueDate == date) AgendaEvent(kind: AgendaEventKind.due, groupId: g.id ?? '', groupName: g.name ?? ''),
      for (final g in groups)
        if (g.nextDrawDate == date)
          AgendaEvent(kind: AgendaEventKind.draw, groupId: g.id ?? '', groupName: g.name ?? ''),
    ]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return AgendaDay(date: date, isToday: date == today, events: events);
  }
}

@Riverpod(keepAlive: true)
BuildAgendaUseCase buildAgendaUseCase(Ref ref) => const BuildAgendaUseCase();
