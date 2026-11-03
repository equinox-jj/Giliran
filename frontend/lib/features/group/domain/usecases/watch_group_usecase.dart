import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/group.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../repositories/group_repository.dart';

part 'watch_group_usecase.g.dart';

/// One cached group by id, live; `null` until it has been fetched.
class const WatchGroupUseCase(final GroupRepository _repository) implements StreamUseCase<GroupDetail?, String> {
  @override
  Stream<Either<Failure, GroupDetail?>> call(String params) => _repository.watchGroup(params);
}

@Riverpod(keepAlive: true)
WatchGroupUseCase watchGroupUseCase(Ref ref) => WatchGroupUseCase(ref.watch(groupRepositoryProvider));
