import 'package:drift/drift.dart';

import 'groups_table.dart';
import 'sync_columns.dart';

/// Cached group members from the API `Member` resource. Each member holds one
/// slot in the MVP, so slot fields live here instead of a separate table.
@DataClassName('MemberRow')
@TableIndex(name: 'members_group_slot_idx', columns: {#groupId, #slotNo})
class Members extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId =>
      text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get avatarUrl => text().nullable()();
  BoolColumn get isGuest => boolean()();
  TextColumn get guestPhone => text().nullable()();
  TextColumn get role => text()();
  TextColumn get status => text()();
  TextColumn get slotId => text()();
  IntColumn get slotNo => integer()();
  IntColumn get fixedOrderPosition => integer().nullable()();
  BoolColumn get hasWon => boolean()();
  IntColumn get wonPeriodNo => integer().nullable()();
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get isStrict => true;
}
