import '../../../../core/database/app_database.dart';

/// The cached groups in the on-device database.
abstract interface class GroupLocalDataSource() {
  /// Cached groups whose status is in [statuses], soonest due first.
  Stream<List<GroupRow>> watchGroups(Set<String> statuses);

  Stream<GroupRow?> watchGroup(String id);

  /// Writes a list fetch: upserts [rows] and drops cached groups with a
  /// status in [statuses] that the server no longer returns.
  Future<void> replaceGroups(List<GroupsCompanion> rows, Set<String> statuses);

  Future<void> upsertGroup(GroupsCompanion row);

  Future<void> deleteGroup(String id);
}
