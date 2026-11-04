import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/members_dao.dart';
import 'member_local_data_source.dart';

part 'member_local_data_source_impl.g.dart';

class MemberLocalDataSourceImpl(final MembersDao _dao) with BaseLocalDataSource implements MemberLocalDataSource {
  @override
  Stream<List<MemberRow>> watchMembers(String groupId) => _dao.watchByGroup(groupId);

  @override
  Stream<MemberRow?> watchMember(String memberId) => _dao.watchById(memberId);

  @override
  Future<void> replaceMembers(String groupId, List<MembersCompanion> rows) =>
      safeCacheCall(() => _dao.replaceForGroup(groupId, rows));

  @override
  Future<void> upsertMembers(List<MembersCompanion> rows) => safeCacheCall(() => _dao.upsertAll(rows));

  @override
  Future<void> deleteMember(String memberId) => safeCacheCall(() => _dao.deleteById(memberId));
}

@Riverpod(keepAlive: true)
MemberLocalDataSource memberLocalDataSource(Ref ref) =>
    MemberLocalDataSourceImpl(ref.watch(appDatabaseProvider).membersDao);
