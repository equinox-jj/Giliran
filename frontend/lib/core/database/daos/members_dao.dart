import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/members_table.dart';

part 'members_dao.g.dart';

/// Reads and writes cached [Members].
@DriftAccessor(tables: [Members])
class MembersDao extends DatabaseAccessor<AppDatabase> with _$MembersDaoMixin {
  MembersDao(super.attachedDatabase);

  /// A group's members ordered by slot number.
  Stream<List<MemberRow>> watchByGroup(String groupId) =>
      (select(members)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.slotNo)]))
          .watch();

  /// Replaces a group's members with a full server fetch.
  Future<void> replaceForGroup(String groupId, List<MembersCompanion> rows) => transaction(() async {
    await (delete(members)..where((m) => m.groupId.equals(groupId))).go();
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      await into(members).insert(
        row.copyWith(
          groupId: Value(groupId),
          syncedAt: Value(now),
          pendingSync: const Value(false),
        ),
      );
    }
  });

  /// Inserts or updates single members (after a guest edit, a join, etc.).
  Future<void> upsertAll(List<MembersCompanion> rows) => transaction(() async {
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      await into(members).insertOnConflictUpdate(
        row.copyWith(syncedAt: Value(now), pendingSync: const Value(false)),
      );
    }
  });
}
