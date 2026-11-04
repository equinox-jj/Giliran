import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/utils/enums/payment_method.dart';
import '../entities/payment.dart';
import '../entities/payout.dart';
import '../entities/period.dart';

/// Periods, payment boards and payouts: cached reads that refresh from the
/// API (server wins), and payment writes that take an [IdempotencyKey].
abstract interface class PaymentRepository() {
  Stream<Either<Failure, List<Period>>> watchPeriods(String groupId);

  Future<Either<Failure, Unit>> refreshPeriods(String groupId);

  Stream<Either<Failure, List<Payment>>> watchPeriodPayments(String periodId);

  /// Fetches a period's board and summary into the cache.
  Future<Either<Failure, Unit>> refreshPeriodPayments(String groupId, String periodId);

  /// One payment with every proof, fresh from the API.
  Future<Either<Failure, Payment>> getPaymentDetail(String groupId, String paymentId);

  Future<Either<Failure, Payment>> uploadProof(
    String groupId,
    String paymentId,
    String path, {
    required IdempotencyKey key,
    void Function(double progress)? onProgress,
  });

  Future<Either<Failure, Payment>> approvePayment(String groupId, String paymentId, {required IdempotencyKey key});

  Future<Either<Failure, Payment>> rejectPayment(
    String groupId,
    String paymentId, {
    required String reason,
    required IdempotencyKey key,
  });

  /// Marks a payment paid. Without a connection the mark is saved on the
  /// device with `pendingSync` and sent later by [syncPendingPayments].
  Future<Either<Failure, Payment>> markPaid(
    String groupId,
    String paymentId, {
    required PaymentMethod method,
    String? note,
    required IdempotencyKey key,
  });

  /// Sends every queued offline mark with its stored key.
  Future<Either<Failure, SyncReport>> syncPendingPayments();

  Stream<Either<Failure, Payout?>> watchPayout(String periodId);

  Future<Either<Failure, Payout>> getPayout(String groupId, String periodId);

  Future<Either<Failure, Payout>> recordPayout(
    String groupId,
    String periodId, {
    String? proofPath,
    String? note,
    required IdempotencyKey key,
  });

  Future<Either<Failure, Payout>> confirmPayout(String groupId, String periodId, {required IdempotencyKey key});
}
