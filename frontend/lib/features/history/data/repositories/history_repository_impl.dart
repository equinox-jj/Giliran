import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/repositories/history_repository.dart';
import '../datasource/history_local_data_source.dart';
import '../datasource/history_local_data_source_impl.dart';
import '../datasource/history_remote_data_source.dart';
import '../datasource/history_remote_data_source_impl.dart';
import '../mappers/activity_mapper.dart';

part 'history_repository_impl.g.dart';

class HistoryRepositoryImpl(final HistoryRemoteDataSource _remote, final HistoryLocalDataSource _local)
    with BaseRepository
    implements HistoryRepository {
  @override
  Stream<Either<Failure, List<ActivityEntry>>> watchActivity(String groupId) =>
      safeStream(_local.watchActivity(groupId).map((rows) => [for (final r in rows) r.toEntity()]));

  @override
  Future<Either<Failure, ActivityCursor>> refreshActivity(String groupId) => safeCall(() async {
    // The newest page replaces the cache, so no gap is left between it and
    // older cached entries; older pages come back through loadMore.
    final page = await _remote.getActivity(groupId);
    await _local.replaceActivity(groupId, [for (final e in page.items) ?e.toCompanion(groupId)]);
    return ActivityCursor(nextCursor: page.nextCursor, hasMore: page.hasMore);
  });

  @override
  Future<Either<Failure, ActivityCursor>> loadMoreActivity(String groupId, String cursor) => safeCall(() async {
    final page = await _remote.getActivity(groupId, cursor: cursor);
    await _local.addActivity(groupId, [for (final e in page.items) ?e.toCompanion(groupId)]);
    return ActivityCursor(nextCursor: page.nextCursor, hasMore: page.hasMore);
  });
}

@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) =>
    HistoryRepositoryImpl(ref.watch(historyRemoteDataSourceProvider), ref.watch(historyLocalDataSourceProvider));
