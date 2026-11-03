import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/groups_table.dart';

part 'groups_dao.g.dart';

/// Reads and writes cached [Groups].
@DriftAccessor(tables: [Groups])
class GroupsDao(super.attachedDatabase) extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  /// The home list: every cached group, newest-first by status then name.
  Stream<List<GroupRow>> watchAll() =>
      (select(groups)..orderBy([
            (g) => OrderingTerm.asc(g.status),
            (g) => OrderingTerm.asc(g.name),
          ]))
          .watch();

  /// Cached groups whose `status` is in [statuses], soonest due date first
  /// (groups without one last), then by name, like `GET /me/groups`.
  Stream<List<GroupRow>> watchByStatuses(Set<String> statuses) =>
      (select(groups)
            ..where((g) => g.status.isIn(statuses))
            ..orderBy([
              (g) => OrderingTerm(
                expression: g.nextDueDate,
                nulls: NullsOrder.last,
              ),
              (g) => OrderingTerm.asc(g.name),
            ]))
          .watch();

  Stream<GroupRow?> watchById(String id) => (select(groups)..where((g) => g.id.equals(id))).watchSingleOrNull();

  Future<GroupRow?> getById(String id) => (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();

  /// Inserts or updates [rows]. Only the columns present in each companion
  /// are updated, so a `GroupSummary` upsert keeps the detail-only columns.
  Future<void> upsertAll(List<GroupsCompanion> rows) => transaction(() => _upsert(rows));

  /// Replaces the home list with a full server fetch: upserts [rows] and
  /// deletes groups the server no longer returns (with all their children),
  /// except rows still waiting to sync.
  Future<void> replaceAll(List<GroupsCompanion> rows) => transaction(() async {
    await _upsert(rows);
    final ids = rows.map((r) => r.id.value).toList();
    await (delete(
      groups,
    )..where((g) => g.id.isNotIn(ids) & g.pendingSync.equals(false))).go();
  });

  /// Like [replaceAll], for a filtered fetch: only cached groups whose
  /// status is in [statuses] and that the server no longer returns are
  /// deleted, so refreshing the active list keeps finished groups.
  Future<void> replaceWhere(List<GroupsCompanion> rows, Set<String> statuses) => transaction(() async {
    await _upsert(rows);
    final ids = rows.map((r) => r.id.value).toList();
    await (delete(groups)..where(
          (g) => g.id.isNotIn(ids) & g.status.isIn(statuses) & g.pendingSync.equals(false),
        ))
        .go();
  });

  Future<void> deleteById(String id) => (delete(groups)..where((g) => g.id.equals(id))).go();

  Future<void> _upsert(List<GroupsCompanion> rows) async {
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      await into(groups).insertOnConflictUpdate(
        row.copyWith(syncedAt: Value(now), pendingSync: const Value(false)),
      );
    }
  }
}
