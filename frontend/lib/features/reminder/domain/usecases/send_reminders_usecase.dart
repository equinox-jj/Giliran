import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/problem_details.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../entities/reminder_result.dart';
import '../repositories/reminder_repository.dart';

part 'send_reminders_usecase.g.dart';

typedef SendRemindersParams = ({String groupId, String periodId, List<String> memberIds, IdempotencyKey key});

/// Pushes a reminder to the selected unpaid members (S41). An empty
/// selection fails with a [ValidationFailure] on `member_ids` before any
/// request, because the API would read a missing list as "everyone". A
/// retry must reuse the same [IdempotencyKey].
class const SendRemindersUseCase(final ReminderRepository _repository)
    implements UseCase<ReminderResult, SendRemindersParams> {
  @override
  Future<Either<Failure, ReminderResult>> call(SendRemindersParams params) async {
    if (params.memberIds.isEmpty) {
      return const Left(
        Failure.validation(
          fieldErrors: [FieldError(field: 'member_ids', code: 'required', message: '')],
        ),
      );
    }
    return _repository.sendReminders(params.groupId, params.periodId, memberIds: params.memberIds, key: params.key);
  }
}

@Riverpod(keepAlive: true)
SendRemindersUseCase sendRemindersUseCase(Ref ref) => SendRemindersUseCase(ref.watch(reminderRepositoryProvider));
