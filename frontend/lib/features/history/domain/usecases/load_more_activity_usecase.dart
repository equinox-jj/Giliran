import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../entities/activity_entry.dart';
import '../repositories/history_repository.dart';

part 'load_more_activity_usecase.g.dart';

/// Fetches the activity page at `cursor` (from the last page's
/// `next_cursor`) into the cache.
class const LoadMoreActivityUseCase(final HistoryRepository _repository)
    implements UseCase<ActivityCursor, ({String groupId, String cursor})> {
  @override
  Future<Either<Failure, ActivityCursor>> call(({String groupId, String cursor}) params) =>
      _repository.loadMoreActivity(params.groupId, params.cursor);
}

@Riverpod(keepAlive: true)
LoadMoreActivityUseCase loadMoreActivityUseCase(Ref ref) =>
    LoadMoreActivityUseCase(ref.watch(historyRepositoryProvider));
