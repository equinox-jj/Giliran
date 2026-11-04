import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_local_data_source.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/payments_dao.dart';
import '../../../../core/database/daos/payouts_dao.dart';
import '../../../../core/database/daos/periods_dao.dart';
import 'payment_local_data_source.dart';

part 'payment_local_data_source_impl.g.dart';

class PaymentLocalDataSourceImpl(
  final PeriodsDao _periods,
  final PaymentsDao _payments,
  final PayoutsDao _payouts,
) with BaseLocalDataSource implements PaymentLocalDataSource {
  @override
  Stream<List<PeriodRow>> watchPeriods(String groupId) => _periods.watchByGroup(groupId);

  @override
  Future<void> upsertPeriods(List<PeriodsCompanion> rows) => safeCacheCall(() => _periods.upsertAll(rows));

  @override
  Future<void> updatePeriodSummary(String periodId, PeriodsCompanion summary) =>
      safeCacheCall(() => _periods.updateSummary(periodId, summary));

  @override
  Stream<List<PaymentRow>> watchPayments(String periodId) => _payments.watchByPeriod(periodId);

  @override
  Stream<PaymentRow?> watchPayment(String paymentId) => _payments.watchById(paymentId);

  @override
  Future<PaymentRow?> getPayment(String paymentId) => safeCacheCall(() => _payments.getById(paymentId));

  @override
  Future<void> replacePayments(String periodId, List<PaymentsCompanion> rows) =>
      safeCacheCall(() => _payments.replaceForPeriod(periodId, rows));

  @override
  Future<void> upsertPayments(List<PaymentsCompanion> rows) => safeCacheCall(() => _payments.upsertAll(rows));

  @override
  Future<List<PaymentRow>> getPendingPayments() => safeCacheCall(_payments.getPending);

  @override
  Future<void> markPendingPaid(
    String paymentId, {
    required String method,
    required String idempotencyKey,
    required DateTime paidAt,
    String? note,
  }) => safeCacheCall(
    () => _payments.markPendingCash(
      paymentId,
      method: method,
      idempotencyKey: idempotencyKey,
      paidAt: paidAt,
      note: note,
    ),
  );

  @override
  Future<void> clearPending(String paymentId) => safeCacheCall(() => _payments.clearPending(paymentId));

  @override
  Stream<PayoutRow?> watchPayout(String periodId) => _payouts.watchByPeriod(periodId);

  @override
  Future<void> upsertPayout(PayoutsCompanion row) => safeCacheCall(() => _payouts.upsert(row));
}

@Riverpod(keepAlive: true)
PaymentLocalDataSource paymentLocalDataSource(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return PaymentLocalDataSourceImpl(db.periodsDao, db.paymentsDao, db.payoutsDao);
}
