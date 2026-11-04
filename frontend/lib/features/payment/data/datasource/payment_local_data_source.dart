import '../../../../core/database/app_database.dart';

/// Cached periods, payment boards and payouts in the on-device database,
/// including offline cash marks waiting to sync.
abstract interface class PaymentLocalDataSource() {
  /// A group's cached periods by period number.
  Stream<List<PeriodRow>> watchPeriods(String groupId);

  Future<void> upsertPeriods(List<PeriodsCompanion> rows);

  Future<void> updatePeriodSummary(String periodId, PeriodsCompanion summary);

  /// A period's cached payment board by slot number.
  Stream<List<PaymentRow>> watchPayments(String periodId);

  Stream<PaymentRow?> watchPayment(String paymentId);

  Future<PaymentRow?> getPayment(String paymentId);

  /// Writes a full board fetch; rows waiting to sync are kept.
  Future<void> replacePayments(String periodId, List<PaymentsCompanion> rows);

  /// Writes server rows and clears their pending flag.
  Future<void> upsertPayments(List<PaymentsCompanion> rows);

  Future<List<PaymentRow>> getPendingPayments();

  Future<void> markPendingPaid(
    String paymentId, {
    required String method,
    required String idempotencyKey,
    required DateTime paidAt,
    String? note,
  });

  Future<void> clearPending(String paymentId);

  /// Copies the current period's cached board onto the group row, so
  /// screens reading the group see the payment change.
  Future<void> syncGroupTallies(String groupId);

  Stream<PayoutRow?> watchPayout(String periodId);

  Future<void> upsertPayout(PayoutsCompanion row);
}
