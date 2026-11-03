import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../entities/group_input.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'create_group_usecase.g.dart';

/// Creates a group with the caller as organizer (feature 14). Values
/// outside [GroupRules] fail with a [ValidationFailure] before any request.
class const CreateGroupUseCase(final GroupRepository _repository) implements UseCase<GroupDetail, CreateGroupInput> {
  @override
  Future<Either<Failure, GroupDetail>> call(CreateGroupInput params) async {
    final errors = GroupRules.check(
      name: params.name,
      amount: params.amount,
      totalSlots: params.totalSlots,
      reminderDaysBefore: params.reminderDaysBefore,
    );
    if (errors.isNotEmpty) return Left(Failure.validation(fieldErrors: errors));
    return _repository.createGroup(params);
  }
}

@Riverpod(keepAlive: true)
CreateGroupUseCase createGroupUseCase(Ref ref) => CreateGroupUseCase(ref.watch(groupRepositoryProvider));
