import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/enums/group_list_filter.dart';
import '../entities/group_summary.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'watch_my_groups_usecase.g.dart';

/// The cached groups for a list filter, live.
class const WatchMyGroupsUseCase(final GroupRepository _repository)
    implements StreamUseCase<List<GroupSummary>, GroupListFilter> {
  @override
  Stream<Either<Failure, List<GroupSummary>>> call(GroupListFilter params) => _repository.watchMyGroups(params);
}

@Riverpod(keepAlive: true)
WatchMyGroupsUseCase watchMyGroupsUseCase(Ref ref) => WatchMyGroupsUseCase(ref.watch(groupRepositoryProvider));
