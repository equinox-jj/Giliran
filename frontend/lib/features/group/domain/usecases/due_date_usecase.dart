import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/enums/period_type.dart';

part 'due_date_usecase.g.dart';

/// The due date of a period by BR-06, matching the backend's `DueDate`: Create
/// group shows the last one under the slots stepper ("8 periode · selesai Min,
/// 20 Des 2026"). Weekly groups add 7 days per period. Monthly groups keep the
/// start's day of month, clamped to the last day of shorter months without
/// carrying over (Jan 31 gives Feb 28, then Mar 31).
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const DueDateUseCase() {
  /// [start] is the first due date (a business date at UTC midnight) and
  /// [periodNo] is 1-based.
  DateTime call({required DateTime start, required PeriodType periodType, required int periodNo}) {
    final offset = periodNo - 1;
    if (periodType == PeriodType.weekly) return DateTime.utc(start.year, start.month, start.day + 7 * offset);
    final first = DateTime.utc(start.year, start.month + offset);
    final daysInMonth = DateTime.utc(first.year, first.month + 1, 0).day;
    return DateTime.utc(first.year, first.month, start.day > daysInMonth ? daysInMonth : start.day);
  }
}

@Riverpod(keepAlive: true)
DueDateUseCase dueDateUseCase(Ref ref) => const DueDateUseCase();
