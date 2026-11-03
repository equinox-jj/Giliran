import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'refresh_group_usecase.g.dart';

/// Fetches one group into the cache and returns the fresh copy.
class const RefreshGroupUseCase(final GroupRepository _repository) implements UseCase<GroupDetail, String> {
  @override
  Future<Either<Failure, GroupDetail>> call(String params) => _repository.refreshGroup(params);
}

@Riverpod(keepAlive: true)
RefreshGroupUseCase refreshGroupUseCase(Ref ref) => RefreshGroupUseCase(ref.watch(groupRepositoryProvider));
