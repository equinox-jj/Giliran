import 'package:drift/drift.dart';

import 'groups_table.dart';
import 'sync_columns.dart';

/// Cached payment-board rows from the API `Payment` resource, with the payer
/// `MemberRef` and `reviewed_by` flattened into columns. The proof URL is
/// signed and short-lived, so only the proof id is cached.
@DataClassName('PaymentRow')
@TableIndex(
  name: 'payments_period_slot_idx',
  columns: {#periodId, #memberSlotNo},
)
class Payments() extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get periodId => text()();

  TextColumn get memberId => text()();
  TextColumn get memberDisplayName => text()();
  TextColumn get memberAvatarUrl => text().nullable()();
  BoolColumn get memberIsGuest => boolean()();
  IntColumn get memberSlotNo => integer()();

  IntColumn get amount => integer()();
  TextColumn get status => text()();
  TextColumn get method => text().nullable()();
  TextColumn get currentProofId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get rejectReason => text().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get reviewedById => text().nullable()();
  TextColumn get reviewedByName => text().nullable()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  BoolColumn get isMine => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  /// The `Idempotency-Key` of an offline cash mark, reused on every retry so
  /// the server applies it once.
  TextColumn get pendingIdempotencyKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get isStrict => true;
}
