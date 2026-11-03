import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../entities/group_input.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'update_group_usecase.g.dart';

/// Changes a group's settings (S19). Values outside [GroupRules] fail with
/// a [ValidationFailure] before any request. An empty change sends nothing
/// and returns `null`, since the API needs at least one field.
class const UpdateGroupUseCase(final GroupRepository _repository)
    implements UseCase<GroupDetail?, ({String groupId, UpdateGroupInput input})> {
  @override
  Future<Either<Failure, GroupDetail?>> call(({String groupId, UpdateGroupInput input}) params) async {
    final input = params.input;
    if (input == const UpdateGroupInput()) return const Right(null);
    final errors = GroupRules.check(
      name: input.name,
      amount: input.amount,
      totalSlots: input.totalSlots,
      reminderDaysBefore: input.reminderDaysBefore,
    );
    if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    return _repository.updateGroup(params.groupId, input);
  }
}

@Riverpod(keepAlive: true)
UpdateGroupUseCase updateGroupUseCase(Ref ref) => UpdateGroupUseCase(ref.watch(groupRepositoryProvider));
