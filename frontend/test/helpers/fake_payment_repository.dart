import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:giliran/core/error/failure.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/features/payment/domain/entities/payment.dart';
import 'package:giliran/features/payment/domain/entities/payout.dart';
import 'package:giliran/features/payment/domain/entities/period.dart';
import 'package:giliran/features/payment/domain/repositories/payment_repository.dart';

/// Records each call and its idempotency key, and answers with the
/// configured results. The watch streams start with [periods] / [payments]
/// and re-emit on [emitPeriods] / [emitPayments]. A write answers from
/// [writeResults] (for retries) before [paymentResult].
class FakePaymentRepository() implements PaymentRepository {
  final calls = <String>[];
  final keys = <String>[];
  String? lastReason;
  PaymentMethod? lastMethod;
  String? lastNote;
  String? lastPath;

  List<Period> periods = [];
  List<Payment> payments = [];

  Either<Failure, Unit> refreshResult = const Right(unit);
  Either<Failure, Payment> paymentResult = const Right(Payment(id: 'pay1'));
  Either<Failure, Payment>? detailResult;
  Either<Failure, SyncReport> syncResult = const Right(SyncReport());

  /// Answers for the next writes, in order, before [paymentResult].
  final writeResults = <Either<Failure, Payment>>[];

  /// When set, uploads wait for it to complete.
  Completer<void>? uploadGate;

  final _periods = StreamController<List<Period>>.broadcast();
  final _payments = StreamController<List<Payment>>.broadcast();

  void emitPeriods(List<Period> value) {
    periods = value;
    _periods.add(value);
  }

  void emitPayments(List<Payment> value) {
    payments = value;
    _payments.add(value);
  }

  Either<Failure, Payment> _write(String name, IdempotencyKey key) {
    calls.add(name);
    keys.add(key.value);
    return writeResults.isNotEmpty ? writeResults.removeAt(0) : paymentResult;
  }

  @override
  Stream<Either<Failure, List<Period>>> watchPeriods(String groupId) async* {
    yield Right(periods);
    yield* _periods.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, Unit>> refreshPeriods(String groupId) async {
    calls.add('refreshPeriods');
    return refreshResult;
  }

  @override
  Stream<Either<Failure, List<Payment>>> watchPeriodPayments(String periodId) async* {
    yield Right(payments);
    yield* _payments.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, Unit>> refreshPeriodPayments(String groupId, String periodId) async {
    calls.add('refreshPeriodPayments:$periodId');
    return refreshResult;
  }

  @override
  Future<Either<Failure, Payment>> getPaymentDetail(String groupId, String paymentId) async {
    calls.add('getPaymentDetail:$paymentId');
    return detailResult ?? Right(payments.firstWhere((p) => p.id == paymentId, orElse: () => Payment(id: paymentId)));
  }

  @override
  Future<Either<Failure, Payment>> uploadProof(
    String groupId,
    String paymentId,
    String path, {
    required IdempotencyKey key,
    void Function(double progress)? onProgress,
  }) async {
    lastPath = path;
    onProgress?.call(0.5);
    await uploadGate?.future;
    return _write('uploadProof', key);
  }

  @override
  Future<Either<Failure, Payment>> approvePayment(
    String groupId,
    String paymentId, {
    required IdempotencyKey key,
  }) async => _write('approvePayment', key);

  @override
  Future<Either<Failure, Payment>> rejectPayment(
    String groupId,
    String paymentId, {
    required String reason,
    required IdempotencyKey key,
  }) async {
    lastReason = reason;
    return _write('rejectPayment', key);
  }

  @override
  Future<Either<Failure, Payment>> markPaid(
    String groupId,
    String paymentId, {
    required PaymentMethod method,
    String? note,
    required IdempotencyKey key,
  }) async {
    lastMethod = method;
    lastNote = note;
    return _write('markPaid', key);
  }

  @override
  Future<Either<Failure, SyncReport>> syncPendingPayments() async {
    calls.add('syncPendingPayments');
    return syncResult;
  }

  @override
  Stream<Either<Failure, Payout?>> watchPayout(String periodId) => Stream.value(const Right(null));

  @override
  Future<Either<Failure, Payout>> getPayout(String groupId, String periodId) async => const Right(Payout(id: 'po1'));

  @override
  Future<Either<Failure, Payout>> recordPayout(
    String groupId,
    String periodId, {
    String? proofPath,
    String? note,
    required IdempotencyKey key,
  }) async => const Right(Payout(id: 'po1'));

  @override
  Future<Either<Failure, Payout>> confirmPayout(
    String groupId,
    String periodId, {
    required IdempotencyKey key,
  }) async => const Right(Payout(id: 'po1'));
}
