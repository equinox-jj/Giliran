import '../../../../core/network/idempotency.dart';
import 'model/payment_model.dart';
import 'model/payout_model.dart';
import 'model/period_model.dart';

/// A period's payment board and its `meta.summary`.
typedef PaymentBoardModel = ({List<PaymentModel> payments, PaymentSummaryModel? summary});

/// Periods, payments and payouts on the API. Every write takes the
/// [IdempotencyKey] of the user's intent.
abstract interface class PaymentRemoteDataSource() {
  Future<List<PeriodModel>> listPeriods(String groupId);

  Future<PeriodModel> getPeriod(String groupId, String periodId);

  Future<PaymentBoardModel> getPaymentBoard(String groupId, String periodId);

  Future<PaymentModel> getPayment(String groupId, String paymentId);

  /// Uploads [path] as the payment's proof; [onProgress] gets 0..1.
  Future<PaymentModel> uploadProof(
    String groupId,
    String paymentId,
    String path, {
    required IdempotencyKey key,
    void Function(double progress)? onProgress,
  });

  Future<PaymentModel> approvePayment(String groupId, String paymentId, {required IdempotencyKey key});

  Future<PaymentModel> rejectPayment(
    String groupId,
    String paymentId, {
    required String reason,
    required IdempotencyKey key,
  });

  /// Marks a payment paid. [paidAt] backdates it to when the money changed
  /// hands (an offline mark sent later); null means now.
  Future<PaymentModel> markPaid(
    String groupId,
    String paymentId, {
    required String method,
    String? note,
    DateTime? paidAt,
    required IdempotencyKey key,
  });

  Future<PayoutModel> getPayout(String groupId, String periodId);

  Future<PayoutModel> recordPayout(
    String groupId,
    String periodId, {
    String? proofPath,
    String? note,
    required IdempotencyKey key,
  });

  Future<PayoutModel> confirmPayout(String groupId, String periodId, {required IdempotencyKey key});
}
