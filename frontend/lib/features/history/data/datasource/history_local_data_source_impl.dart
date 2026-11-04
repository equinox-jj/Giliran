import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/activity_logs_dao.dart';
import 'history_local_data_source.dart';

part 'history_local_data_source_impl.g.dart';

class HistoryLocalDataSourceImpl(final ActivityLogsDao _activity)
    with BaseLocalDataSource
    implements HistoryLocalDataSource {
  @override
  Stream<List<ActivityLogRow>> watchActivity(String groupId) =>
      _activity.watchByGroup(groupId, limit: ActivityLogsDao.maxPerGroup);

  @override
  Future<void> replaceActivity(String groupId, List<ActivityLogsCompanion> rows) =>
      safeCacheCall(() => _activity.replaceForGroup(groupId, rows));

  @override
  Future<void> addActivity(String groupId, List<ActivityLogsCompanion> rows) =>
      safeCacheCall(() => _activity.upsertAll(groupId, rows));
}

@Riverpod(keepAlive: true)
HistoryLocalDataSource historyLocalDataSource(Ref ref) =>
    HistoryLocalDataSourceImpl(ref.watch(appDatabaseProvider).activityLogsDao);
