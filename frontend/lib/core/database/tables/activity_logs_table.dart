import 'package:drift/drift.dart';

import '../converters.dart';
import 'groups_table.dart';
import 'sync_columns.dart';

/// Cached activity log entries from the API `ActivityEntry` resource. Only
/// the latest entries per group are kept (see `ActivityLogsDao`).
@DataClassName('ActivityLogRow')
@TableIndex.sql(
  'CREATE INDEX activity_logs_group_created_idx '
  'ON activity_logs (group_id, created_at DESC, id DESC)',
)
class ActivityLogs extends Table with SyncColumns {
  /// Opaque server id (a stringified bigint).
  TextColumn get id => text()();
  TextColumn get groupId =>
      text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();

  TextColumn get actorId => text().nullable()();
  TextColumn get actorName => text().nullable()();
  TextColumn get actorAvatarUrl => text().nullable()();

  TextColumn get subjectMemberId => text().nullable()();
  TextColumn get subjectDisplayName => text().nullable()();
  IntColumn get subjectSlotNo => integer().nullable()();

  TextColumn get before => text().map(const JsonMapConverter()).nullable()();
  TextColumn get after => text().map(const JsonMapConverter()).nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get isStrict => true;
}
