import 'package:drift/drift.dart';

/// Sync bookkeeping shared by every mirrored table (DB_SCHEME §9).
///
/// [syncedAt] is the last time the row matched the server; [pendingSync]
/// marks a local change not yet sent (an organizer marking a cash payment
/// offline). Server state wins on conflict.
mixin SyncColumns on Table {
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
}
