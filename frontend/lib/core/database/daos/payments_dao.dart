import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/payments_table.dart';

part 'payments_dao.g.dart';

/// Reads and writes cached [Payments], including offline cash marks waiting
/// to sync (PRD §9, "Organizer offline when marking cash payment").
@DriftAccessor(tables: [Payments])
class PaymentsDao extends DatabaseAccessor<AppDatabase> with _$PaymentsDaoMixin {
  PaymentsDao(super.attachedDatabase);

  /// A period's payment board ordered by slot number.
  Stream<List<PaymentRow>> watchByPeriod(String periodId) =>
      (select(payments)
            ..where((p) => p.periodId.equals(periodId))
            ..orderBy([(p) => OrderingTerm.asc(p.memberSlotNo)]))
          .watch();

  Stream<PaymentRow?> watchById(String id) => (select(payments)..where((p) => p.id.equals(id))).watchSingleOrNull();

  /// Every payment with a local change waiting to be sent.
  Stream<List<PaymentRow>> watchPending() => (select(payments)..where((p) => p.pendingSync.equals(true))).watch();

  Future<List<PaymentRow>> getPending() => (select(payments)..where((p) => p.pendingSync.equals(true))).get();

  /// Replaces a period's board with a full server fetch. Rows still waiting
  /// to sync are left alone until the sync resolves them.
  Future<void> replaceForPeriod(
    String periodId,
    List<PaymentsCompanion> rows,
  ) => transaction(() async {
    final pendingIds =
        await (selectOnly(payments)
              ..addColumns([payments.id])
              ..where(
                payments.periodId.equals(periodId) & payments.pendingSync.equals(true),
              ))
            .map((r) => r.read(payments.id)!)
            .get();
    await (delete(payments)..where(
          (p) => p.periodId.equals(periodId) & p.pendingSync.equals(false),
        ))
        .go();
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      if (pendingIds.contains(row.id.value)) continue;
      await into(payments).insert(
        row.copyWith(
          periodId: Value(periodId),
          syncedAt: Value(now),
          pendingSync: const Value(false),
        ),
      );
    }
  });

  /// Inserts or updates single payments from the server (after an approve,
  /// reject or a synced cash mark). Clears any pending flag on them.
  Future<void> upsertAll(List<PaymentsCompanion> rows) => transaction(() async {
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      await into(payments).insertOnConflictUpdate(
        row.copyWith(
          syncedAt: Value(now),
          pendingSync: const Value(false),
          pendingIdempotencyKey: const Value(null),
        ),
      );
    }
  });

  /// Records an offline "marked paid in cash" on payment [id], to be sent
  /// later with [idempotencyKey].
  Future<void> markPendingCash(
    String id, {
    required String idempotencyKey,
    required DateTime paidAt,
    String? note,
  }) => (update(payments)..where((p) => p.id.equals(id))).write(
    PaymentsCompanion(
      status: const Value('paid'),
      method: const Value('cash'),
      note: Value(note),
      paidAt: Value(paidAt.toUtc()),
      updatedAt: Value(DateTime.now().toUtc()),
      pendingSync: const Value(true),
      pendingIdempotencyKey: Value(idempotencyKey),
    ),
  );

  /// Drops the pending flag on [id] without touching its data, for a change
  /// the server rejected (the next fetch restores server state).
  Future<void> clearPending(String id) => (update(payments)..where((p) => p.id.equals(id))).write(
    const PaymentsCompanion(
      pendingSync: Value(false),
      pendingIdempotencyKey: Value(null),
    ),
  );
}
