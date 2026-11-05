import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../entities/recap.dart';
import '../repositories/reminder_repository.dart';

part 'get_recap_usecase.g.dart';

typedef RecapRef = ({String groupId, String periodId});

/// A period's recap (S41): counts, unpaid members and payment info for the
/// WhatsApp image and messages.
class const GetRecapUseCase(final ReminderRepository _repository) implements UseCase<Recap, RecapRef> {
  @override
  Future<Either<Failure, Recap>> call(RecapRef params) => _repository.getRecap(params.groupId, params.periodId);
}

@Riverpod(keepAlive: true)
GetRecapUseCase getRecapUseCase(Ref ref) => GetRecapUseCase(ref.watch(reminderRepositoryProvider));
