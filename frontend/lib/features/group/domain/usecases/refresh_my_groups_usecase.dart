import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/group_list_filter.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'refresh_my_groups_usecase.g.dart';

/// Fetches the group list for a filter into the cache.
class const RefreshMyGroupsUseCase(final GroupRepository _repository) implements UseCase<Unit, GroupListFilter> {
  @override
  Future<Either<Failure, Unit>> call(GroupListFilter params) => _repository.refreshMyGroups(params);
}

@Riverpod(keepAlive: true)
RefreshMyGroupsUseCase refreshMyGroupsUseCase(Ref ref) => RefreshMyGroupsUseCase(ref.watch(groupRepositoryProvider));
