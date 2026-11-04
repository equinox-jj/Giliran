import '../../../../core/database/app_database.dart';

/// The cached activity log (DB_SCHEME §9: the latest 200 entries per
/// group).
abstract interface class HistoryLocalDataSource() {
  Stream<List<ActivityLogRow>> watchActivity(String groupId);

  /// Drops the group's cached entries and stores [rows] instead.
  Future<void> replaceActivity(String groupId, List<ActivityLogsCompanion> rows);

  Future<void> addActivity(String groupId, List<ActivityLogsCompanion> rows);
}
