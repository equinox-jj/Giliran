import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/periods_table.dart';

part 'periods_dao.g.dart';

/// Reads and writes cached [Periods].
@DriftAccessor(tables: [Periods])
class PeriodsDao(super.attachedDatabase) extends DatabaseAccessor<AppDatabase> with _$PeriodsDaoMixin {
  /// A group's periods ordered by period number.
  Stream<List<PeriodRow>> watchByGroup(String groupId) =>
      (select(periods)
            ..where((p) => p.groupId.equals(groupId))
            ..orderBy([(p) => OrderingTerm.asc(p.periodNo)]))
          .watch();

  Stream<PeriodRow?> watchById(String id) => (select(periods)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<void> upsertAll(List<PeriodsCompanion> rows) => transaction(() async {
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      await into(periods).insertOnConflictUpdate(
        row.copyWith(syncedAt: Value(now), pendingSync: const Value(false)),
      );
    }
  });

  /// Writes a fresh payment summary (from the board's `meta.summary`) onto
  /// period [id].
  Future<void> updateSummary(String id, PeriodsCompanion summary) =>
      (update(periods)..where((p) => p.id.equals(id))).write(summary);
}
