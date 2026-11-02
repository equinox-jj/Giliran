import 'package:drift/drift.dart';

import 'groups_table.dart';
import 'sync_columns.dart';

/// Cached periods (rounds) from the API `Period` resource, with the winner
/// `MemberRef` and `PaymentSummary` flattened into columns.
@DataClassName('PeriodRow')
class Periods extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id, onDelete: KeyAction.cascade)();
  IntColumn get periodNo => integer()();

  /// `yyyy-MM-dd`, Asia/Jakarta business date.
  TextColumn get dueDate => text()();

  /// `yyyy-MM-dd`, Asia/Jakarta business date.
  TextColumn get drawDate => text()();
  TextColumn get status => text()();
  TextColumn get seedHash => text().nullable()();
  TextColumn get verificationCode => text().nullable()();
  DateTimeColumn get drawnAt => dateTime().nullable()();

  TextColumn get winnerMemberId => text().nullable()();
  TextColumn get winnerDisplayName => text().nullable()();
  TextColumn get winnerAvatarUrl => text().nullable()();
  BoolColumn get winnerIsGuest => boolean().nullable()();
  IntColumn get winnerSlotNo => integer().nullable()();

  IntColumn get summaryTotalCount => integer().nullable()();
  IntColumn get summaryPaidCount => integer().nullable()();
  IntColumn get summaryPendingReviewCount => integer().nullable()();
  IntColumn get summaryUnpaidCount => integer().nullable()();
  IntColumn get summaryRejectedCount => integer().nullable()();
  IntColumn get summaryCollectedAmount => integer().nullable()();
  IntColumn get summaryExpectedAmount => integer().nullable()();

  BoolColumn get payoutRecorded => boolean().withDefault(const Constant(false))();
  BoolColumn get payoutConfirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {groupId, periodNo},
  ];

  @override
  bool get isStrict => true;
}
