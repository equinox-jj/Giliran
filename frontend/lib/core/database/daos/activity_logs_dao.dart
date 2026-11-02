import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/activity_logs_table.dart';

part 'activity_logs_dao.g.dart';

/// Reads and writes cached [ActivityLogs], keeping only the latest
/// [maxPerGroup] entries per group (DB_SCHEME §9).
@DriftAccessor(tables: [ActivityLogs])
class ActivityLogsDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogsDaoMixin {
  ActivityLogsDao(super.attachedDatabase);

  static const maxPerGroup = 200;

  /// A group's newest entries first.
  Stream<List<ActivityLogRow>> watchByGroup(
    String groupId, {
    int limit = 50,
  }) => (_newestFirst(groupId)..limit(limit)).watch();

  /// The page of entries older than the [before] row (keyset pagination).
  Future<List<ActivityLogRow>> pageBefore(
    String groupId, {
    required ActivityLogRow before,
    int limit = 50,
  }) =>
      (_newestFirst(groupId)
            ..where(
              (a) =>
                  a.createdAt.isSmallerThanValue(before.createdAt) |
                  (a.createdAt.equals(before.createdAt) &
                      a.id.isSmallerThanValue(before.id)),
            )
            ..limit(limit))
          .get();

  /// Inserts or updates [rows] for [groupId], then trims the group to the
  /// latest [maxPerGroup] entries.
  Future<void> upsertAll(String groupId, List<ActivityLogsCompanion> rows) =>
      transaction(() async {
        final now = DateTime.now().toUtc();
        for (final row in rows) {
          await into(activityLogs).insertOnConflictUpdate(
            row.copyWith(
              groupId: Value(groupId),
              syncedAt: Value(now),
              pendingSync: const Value(false),
            ),
          );
        }
        await trimToLatest(groupId, maxPerGroup);
      });

  /// Deletes all but the newest [keep] entries of [groupId].
  Future<void> trimToLatest(String groupId, int keep) => customUpdate(
    'DELETE FROM activity_logs WHERE group_id = ?1 AND id NOT IN ('
    'SELECT id FROM activity_logs WHERE group_id = ?1 '
    'ORDER BY created_at DESC, id DESC LIMIT ?2)',
    variables: [Variable.withString(groupId), Variable.withInt(keep)],
    updates: {activityLogs},
    updateKind: UpdateKind.delete,
  );

  SimpleSelectStatement<$ActivityLogsTable, ActivityLogRow> _newestFirst(
    String groupId,
  ) => select(activityLogs)
    ..where((a) => a.groupId.equals(groupId))
    ..orderBy([
      (a) => OrderingTerm.desc(a.createdAt),
      (a) => OrderingTerm.desc(a.id),
    ]);
}
