import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/api_error_code.dart';
import '../../../group/data/repositories/group_repository_impl.dart';
import '../../../group/domain/repositories/group_repository.dart';

part 'resolve_reminder_period_usecase.g.dart';

/// The period Reminders and recap (S41) is about: the group's current
/// period (the first `open` or `drawn` one), fetched fresh because the
/// recap needs a connection anyway. A group without one fails with
/// `period_not_open`.
class const ResolveReminderPeriodUseCase(final GroupRepository _groups) implements UseCase<String, String> {
  @override
  Future<Either<Failure, String>> call(String params) async {
    final result = await _groups.refreshGroup(params);
    return result.flatMap(
      (group) => switch (group.currentPeriodId) {
        final id? => Right(id),
        null => const Left(Failure.conflict(code: ApiErrorCode.periodNotOpen)),
      },
    );
  }
}

@Riverpod(keepAlive: true)
ResolveReminderPeriodUseCase resolveReminderPeriodUseCase(Ref ref) =>
    ResolveReminderPeriodUseCase(ref.watch(groupRepositoryProvider));
