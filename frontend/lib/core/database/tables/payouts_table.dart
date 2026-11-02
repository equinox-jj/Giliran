import 'package:drift/drift.dart';

import 'groups_table.dart';
import 'sync_columns.dart';

/// Cached payouts (one per period) from the API `Payout` resource.
@DataClassName('PayoutRow')
class Payouts() extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get periodId => text().unique()();

  TextColumn get winnerMemberId => text()();
  TextColumn get winnerDisplayName => text()();
  TextColumn get winnerAvatarUrl => text().nullable()();
  IntColumn get winnerSlotNo => integer()();

  IntColumn get amount => integer()();

  /// The proof URL is signed and short-lived, so only its presence is cached.
  BoolColumn get hasProof => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get recordedById => text()();
  TextColumn get recordedByName => text()();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get isStrict => true;
}
