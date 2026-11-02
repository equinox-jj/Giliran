import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/payouts_table.dart';

part 'payouts_dao.g.dart';

/// Reads and writes cached [Payouts].
@DriftAccessor(tables: [Payouts])
class PayoutsDao extends DatabaseAccessor<AppDatabase> with _$PayoutsDaoMixin {
  PayoutsDao(super.attachedDatabase);

  Stream<PayoutRow?> watchByPeriod(String periodId) => (select(
    payouts,
  )..where((p) => p.periodId.equals(periodId))).watchSingleOrNull();

  Future<void> upsert(PayoutsCompanion row) =>
      into(payouts)
          .insertOnConflictUpdate(
            row.copyWith(
              syncedAt: Value(DateTime.now().toUtc()),
              pendingSync: const Value(false),
            ),
          )
          .then((_) {});
}
