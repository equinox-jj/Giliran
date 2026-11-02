import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Cached arisan groups, filled from both `GroupSummary` (home list) and
/// `Group` (detail). Fields only one of them sends are nullable so either
/// payload can upsert without wiping the other's columns.
@DataClassName('GroupRow')
class Groups extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get amount => integer()();
  IntColumn get potAmount => integer().nullable()();
  TextColumn get periodType => text()();
  IntColumn get totalSlots => integer()();
  IntColumn get filledSlots => integer()();
  TextColumn get drawMethod => text().nullable()();

  /// `yyyy-MM-dd`, Asia/Jakarta business date.
  TextColumn get startDate => text().nullable()();
  IntColumn get reminderDaysBefore => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get myRole => text()();
  TextColumn get myMemberId => text().nullable()();

  TextColumn get organizerId => text().nullable()();
  TextColumn get organizerName => text().nullable()();
  TextColumn get organizerAvatarUrl => text().nullable()();

  TextColumn get inviteCode => text().nullable()();
  TextColumn get inviteUrl => text().nullable()();

  TextColumn get bankName => text().nullable()();
  TextColumn get bankAccountNumber => text().nullable()();
  TextColumn get bankAccountHolder => text().nullable()();
  TextColumn get qrisMerchantName => text().nullable()();

  /// The QRIS image URL is signed and short-lived, so only its presence is
  /// cached.
  BoolColumn get hasQris => boolean().withDefault(const Constant(false))();

  TextColumn get currentPeriodId => text().nullable()();
  IntColumn get currentPeriodNo => integer().nullable()();
  TextColumn get nextDueDate => text().nullable()();
  TextColumn get nextDrawDate => text().nullable()();
  TextColumn get myPaymentStatus => text().nullable()();
  IntColumn get paidCount => integer().nullable()();
  IntColumn get pendingReviewCount => integer().nullable()();
  BoolColumn get iHaveWon => boolean().nullable()();

  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get isStrict => true;
}
