import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../payment/domain/entities/period.dart';
import '../../../domain/entities/schedule.dart';
import '../../../domain/usecases/build_schedule_usecase.dart';

part 'schedule_controller.g.dart';

/// The Jadwal timeline of [periods] on [scale], as of today in
/// Jakarta. [periods] is the group detail's cached list, so it keeps its
/// identity until the cache changes.
@riverpod
Schedule schedule(Ref ref, List<Period> periods, ScheduleScale scale) {
  final today = AppDate.jakartaToday(ref.watch(clockProvider)());
  return ref.watch(buildScheduleUseCaseProvider)((periods: periods, today: today, scale: scale));
}
