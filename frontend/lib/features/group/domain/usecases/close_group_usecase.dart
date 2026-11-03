import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'close_group_usecase.g.dart';

/// Closes a group for good; it stays readable as an archive.
class const CloseGroupUseCase(final GroupRepository _repository) implements UseCase<GroupDetail, String> {
  @override
  Future<Either<Failure, GroupDetail>> call(String params) => _repository.closeGroup(params);
}

@Riverpod(keepAlive: true)
CloseGroupUseCase closeGroupUseCase(Ref ref) => CloseGroupUseCase(ref.watch(groupRepositoryProvider));
