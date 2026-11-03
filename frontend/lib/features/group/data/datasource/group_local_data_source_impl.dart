import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/groups_dao.dart';
import 'group_local_data_source.dart';

part 'group_local_data_source_impl.g.dart';

class GroupLocalDataSourceImpl(final GroupsDao _dao) with BaseLocalDataSource implements GroupLocalDataSource {
  @override
  Stream<List<GroupRow>> watchGroups(Set<String> statuses) => _dao.watchByStatuses(statuses);

  @override
  Stream<GroupRow?> watchGroup(String id) => _dao.watchById(id);

  @override
  Future<void> replaceGroups(List<GroupsCompanion> rows, Set<String> statuses) =>
      safeCacheCall(() => _dao.replaceWhere(rows, statuses));

  @override
  Future<void> upsertGroup(GroupsCompanion row) => safeCacheCall(() => _dao.upsertAll([row]));

  @override
  Future<void> deleteGroup(String id) => safeCacheCall(() => _dao.deleteById(id));
}

@Riverpod(keepAlive: true)
GroupLocalDataSource groupLocalDataSource(Ref ref) =>
    GroupLocalDataSourceImpl(ref.watch(appDatabaseProvider).groupsDao);
