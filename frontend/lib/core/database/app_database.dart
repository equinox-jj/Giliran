import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'converters.dart';
import 'daos/activity_logs_dao.dart';
import 'daos/groups_dao.dart';
import 'daos/members_dao.dart';
import 'daos/payments_dao.dart';
import 'daos/payouts_dao.dart';
import 'daos/periods_dao.dart';
import 'tables/activity_logs_table.dart';
import 'tables/groups_table.dart';
import 'tables/members_table.dart';
import 'tables/payments_table.dart';
import 'tables/payouts_table.dart';
import 'tables/periods_table.dart';

part 'app_database.g.dart';

/// The on-device mirror of server data for offline reading (DB_SCHEME §9).
///
/// The server is the source of truth; these tables are a cache filled from
/// API responses, plus the pending-sync flag for offline cash payments.
/// Feature local datasources reach the tables through the DAO getters.
@DriftDatabase(
  tables: [Groups, Members, Periods, Payments, Payouts, ActivityLogs],
  daos: [
    GroupsDao,
    MembersDao,
    PeriodsDao,
    PaymentsDao,
    PayoutsDao,
    ActivityLogsDao,
  ],
)
class AppDatabase([QueryExecutor? executor]) extends _$AppDatabase {
  /// Opens the app database file, or [executor] when given (tests pass
  /// `NativeDatabase.memory()`).
  this : super(executor ?? _openConnection());

  static const _fileName = 'giliran';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // Per-connection: SQLite defaults it off and then ignores ON DELETE.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Deletes every cached row. Call on sign-out and session expiry so the
  /// next account on this device never sees the previous one's groups.
  Future<void> clearAll() => transaction(() async {
    // Children first is not required (FKs cascade), but keeps it explicit.
    for (final table in allTables.toList().reversed) {
      await delete(table).go();
    }
  });

  static QueryExecutor _openConnection() => driftDatabase(
    name: _fileName,
    native: DriftNativeOptions(
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL');
        // NORMAL is enough for a cache that can be refetched from the API.
        db.execute('PRAGMA synchronous = NORMAL');
        db.execute('PRAGMA foreign_keys = ON');
        db.execute('PRAGMA busy_timeout = 5000');
      },
    ),
  );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
