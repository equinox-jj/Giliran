import 'package:flutter_test/flutter_test.dart';
import 'package:giliran/core/database/app_database.dart';
import 'package:giliran/core/error/exceptions.dart';
import 'package:giliran/core/error/problem_details.dart';
import 'package:giliran/core/network/idempotency.dart';
import 'package:giliran/core/utils/enums/api_error_code.dart';
import 'package:giliran/core/utils/enums/payment_method.dart';
import 'package:giliran/core/utils/enums/payment_status.dart';
import 'package:giliran/core/utils/enums/period_status.dart';
import 'package:giliran/features/payment/data/datasource/model/payment_model.dart';
import 'package:giliran/features/payment/data/datasource/model/payout_model.dart';
import 'package:giliran/features/payment/data/datasource/model/period_model.dart';
import 'package:giliran/features/payment/data/datasource/payment_local_data_source_impl.dart';
import 'package:giliran/features/payment/data/datasource/payment_remote_data_source.dart';
import 'package:giliran/features/payment/data/repositories/payment_repository_impl.dart';

import '../../../../core/database/fixtures.dart';
import '../../fixtures.dart';

/// Answers each call with the configured models, or throws the queued
/// errors for mark-paid.
class _FakeRemote() implements PaymentRemoteDataSource {
  List<PeriodModel> periods = [PeriodModel.fromJson(periodJson('p1'))];
  List<PaymentModel> board = [PaymentModel.fromJson(paymentJson('pay1'))];
  PaymentModel payment = PaymentModel.fromJson(paymentJson('pay1', status: 'paid', method: 'cash'));
  Object? error;

  /// Errors thrown by the next mark-paid calls, in order.
  final markErrors = <Object>[];
  final markKeys = <String>[];
  final markPaidAts = <DateTime?>[];
  final calls = <String>[];

  Future<T> _answer<T>(String name, T value) async {
    calls.add(name);
    if (error case final e?) throw e;
    return value;
  }

  @override
  Future<List<PeriodModel>> listPeriods(String groupId) => _answer('listPeriods', periods);

  @override
  Future<PeriodModel> getPeriod(String groupId, String periodId) => _answer('getPeriod', periods.first);

  @override
  Future<PaymentBoardModel> getPaymentBoard(String groupId, String periodId) => _answer('getPaymentBoard', (
    payments: board,
    summary: PaymentSummaryModel.fromJson(summaryJson),
  ));

  @override
  Future<PaymentModel> getPayment(String groupId, String paymentId) => _answer('getPayment', payment);

  @override
  Future<PaymentModel> uploadProof(
    String groupId,
    String paymentId,
    String path, {
    required IdempotencyKey key,
    void Function(double progress)? onProgress,
  }) => _answer('uploadProof', payment);

  @override
  Future<PaymentModel> approvePayment(String groupId, String paymentId, {required IdempotencyKey key}) =>
      _answer('approvePayment', payment);

  @override
  Future<PaymentModel> rejectPayment(
    String groupId,
    String paymentId, {
    required String reason,
    required IdempotencyKey key,
  }) => _answer('rejectPayment', payment);

  @override
  Future<PaymentModel> markPaid(
    String groupId,
    String paymentId, {
    required String method,
    String? note,
    DateTime? paidAt,
    required IdempotencyKey key,
  }) async {
    calls.add('markPaid');
    markKeys.add(key.value);
    markPaidAts.add(paidAt);
    if (markErrors.isNotEmpty) throw markErrors.removeAt(0);
    return payment;
  }

  @override
  Future<PayoutModel> getPayout(String groupId, String periodId) =>
      _answer('getPayout', PayoutModel.fromJson(payoutJson(periodId)));

  @override
  Future<PayoutModel> recordPayout(
    String groupId,
    String periodId, {
    String? proofPath,
    String? note,
    required IdempotencyKey key,
  }) => _answer('recordPayout', PayoutModel.fromJson(payoutJson(periodId)));

  @override
  Future<PayoutModel> confirmPayout(String groupId, String periodId, {required IdempotencyKey key}) =>
      _answer('confirmPayout', PayoutModel.fromJson(payoutJson(periodId)));
}

ConflictException _conflict(ApiErrorCode code) => ConflictException(
  problem: ProblemDetails(status: 409, code: code, rawCode: code.apiValue),
);

void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late PaymentRepositoryImpl repository;
  final now = DateTime.utc(2026, 11, 3, 5);

  setUp(() async {
    db = openTestDatabase();
    remote = _FakeRemote();
    repository = PaymentRepositoryImpl(
      remote,
      PaymentLocalDataSourceImpl(db.periodsDao, db.paymentsDao, db.payoutsDao),
      () => now,
    );
    await db.groupsDao.upsertAll([groupRow('g1')]);
  });
  tearDown(() => db.close());

  test('refreshPeriods writes periods the watch stream then emits', () async {
    // Arrange
    remote.periods = [
      PeriodModel.fromJson(periodJson('p1', status: 'closed', winner: memberRefJson('m3', slotNo: 3))),
      PeriodModel.fromJson(periodJson('p2', periodNo: 2)),
    ];

    // Act
    await repository.refreshPeriods('g1');

    // Assert
    final periods = (await repository.watchPeriods('g1').first).getOrElse((_) => []);
    expect(periods.map((p) => p.periodNo), [1, 2]);
    expect(periods.first.status, PeriodStatus.closed);
    expect(periods.first.winner?.slotNo, 3);
    expect(periods.last.dueDate, DateTime.utc(2026, 11, 25));
  });

  test('refreshPeriodPayments caches the board and the period summary', () async {
    // Arrange
    await repository.refreshPeriods('g1');
    remote.board = [
      PaymentModel.fromJson(paymentJson('pay1', status: 'paid', method: 'cash')),
      PaymentModel.fromJson(paymentJson('pay2', slotNo: 2, memberId: 'm2', isMine: true)),
    ];

    // Act
    await repository.refreshPeriodPayments('g1', 'p1');

    // Assert
    final payments = (await repository.watchPeriodPayments('p1').first).getOrElse((_) => []);
    expect(payments.map((p) => p.id), ['pay1', 'pay2']);
    expect(payments.first.method, PaymentMethod.cash);
    expect(payments.last.mine, isTrue);
    final period = (await repository.watchPeriods('g1').first).getOrElse((_) => []).single;
    expect(period.paymentSummary?.paidCount, 8);
  });

  test('payment_already_reviewed maps to a failure with that code', () async {
    // Arrange
    remote.error = _conflict(ApiErrorCode.paymentAlreadyReviewed);

    // Act
    final result = await repository.approvePayment('g1', 'pay1', key: const IdempotencyKey('k'));

    // Assert
    expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.paymentAlreadyReviewed);
  });

  test('invalid_payment_state maps to a failure with that code', () async {
    // Arrange
    remote.error = _conflict(ApiErrorCode.invalidPaymentState);

    // Act
    final result = await repository.rejectPayment(
      'g1',
      'pay1',
      reason: 'Nominal kurang',
      key: const IdempotencyKey('k'),
    );

    // Assert
    expect(result.getLeft().toNullable()?.apiCode, ApiErrorCode.invalidPaymentState);
  });

  test('approve caches the server row', () async {
    // Arrange
    await db.paymentsDao.replaceForPeriod('p1', [paymentRow('pay1', 'g1', 'p1', 1, status: 'pending_review')]);
    remote.payment = PaymentModel.fromJson(paymentJson('pay1', status: 'paid'));
    remote.board = [remote.payment];

    // Act
    final result = await repository.approvePayment('g1', 'pay1', key: const IdempotencyKey('k'));

    // Assert
    expect(result.getRight().toNullable()?.status, PaymentStatus.paid);
    final row = await db.paymentsDao.getById('pay1');
    expect(row?.status, 'paid');
  });

  group('offline cash marks', () {
    setUp(() => db.paymentsDao.replaceForPeriod('p1', [paymentRow('pay1', 'g1', 'p1', 1)]));

    test('offline mark is queued with pending_sync', () async {
      // Arrange
      remote.markErrors.add(const NetworkException());

      // Act
      final result = await repository.markPaid(
        'g1',
        'pay1',
        method: PaymentMethod.transfer,
        note: 'Di rumah Bu Ani',
        key: const IdempotencyKey('key-offline'),
      );

      // Assert
      final payment = result.getRight().toNullable();
      expect(payment?.status, PaymentStatus.paid);
      expect(payment?.isPendingSync, isTrue);
      final row = await db.paymentsDao.getById('pay1');
      expect(row?.pendingSync, isTrue);
      expect(row?.pendingIdempotencyKey, 'key-offline');
      expect(row?.method, 'transfer');
      expect(row?.note, 'Di rumah Bu Ani');
      expect(row?.paidAt, now);
    });

    test('a timed-out mark is queued too', () async {
      // Arrange
      remote.markErrors.add(const TimeoutException());

      // Act
      final result = await repository.markPaid(
        'g1',
        'pay1',
        method: PaymentMethod.cash,
        key: const IdempotencyKey('key-timeout'),
      );

      // Assert
      expect(result.getRight().toNullable()?.isPendingSync, isTrue);
    });

    test('sync sends the stored idempotency key', () async {
      // Arrange
      remote.markErrors.add(const NetworkException());
      await repository.markPaid('g1', 'pay1', method: PaymentMethod.cash, key: const IdempotencyKey('key-stored'));
      remote.payment = PaymentModel.fromJson(paymentJson('pay1', status: 'paid', method: 'cash'));

      // Act
      final result = await repository.syncPendingPayments();

      // Assert
      expect(remote.markKeys, ['key-stored', 'key-stored']);
      expect(result.getRight().toNullable()?.synced, 1);
      final row = await db.paymentsDao.getById('pay1');
      expect(row?.pendingSync, isFalse);
      expect(row?.pendingIdempotencyKey, isNull);
    });

    test('sync drops a rejected mark and reports it', () async {
      // Arrange
      remote.markErrors.add(const NetworkException());
      await repository.markPaid('g1', 'pay1', method: PaymentMethod.cash, key: const IdempotencyKey('key-x'));
      remote.markErrors.add(_conflict(ApiErrorCode.invalidPaymentState));
      remote.payment = PaymentModel.fromJson(paymentJson('pay1', status: 'paid', method: 'transfer'));

      // Act
      final result = await repository.syncPendingPayments();

      // Assert
      final report = result.getRight().toNullable();
      expect(report?.synced, 0);
      expect(report?.rejected.single.id, 'pay1');
      expect(report?.rejected.single.method, PaymentMethod.transfer);
      final row = await db.paymentsDao.getById('pay1');
      expect(row?.pendingSync, isFalse);
      expect(row?.method, 'transfer');
    });

    test('sync sends when the money changed hands, not when it reconnected', () async {
      // Arrange
      remote.markErrors.add(const NetworkException());
      await repository.markPaid('g1', 'pay1', method: PaymentMethod.cash, key: const IdempotencyKey('key-at'));

      // Act
      await repository.syncPendingPayments();

      // Assert
      expect(remote.markPaidAts, [null, now]);
    });

    test('a refused paid_at is sent again without it under the same key', () async {
      // Arrange
      remote.markErrors.add(const NetworkException());
      await repository.markPaid('g1', 'pay1', method: PaymentMethod.cash, key: const IdempotencyKey('key-skew'));
      remote.markErrors.add(
        const ValidationException(
          problem: ProblemDetails(
            status: 422,
            code: ApiErrorCode.validationError,
            rawCode: 'validation_error',
            fieldErrors: [FieldError(field: 'paid_at', code: 'maximum_value', message: '')],
          ),
        ),
      );

      // Act
      final result = await repository.syncPendingPayments();

      // Assert
      expect(remote.markPaidAts, [null, now, null]);
      expect(remote.markKeys.toSet(), {'key-skew'});
      expect(result.getRight().toNullable()?.synced, 1);
    });

    test('sync keeps marks queued while still offline', () async {
      // Arrange
      remote.markErrors.addAll([const NetworkException(), const NetworkException()]);
      await repository.markPaid('g1', 'pay1', method: PaymentMethod.cash, key: const IdempotencyKey('key-y'));

      // Act
      final result = await repository.syncPendingPayments();

      // Assert
      expect(result.getRight().toNullable()?.synced, 0);
      expect((await db.paymentsDao.getById('pay1'))?.pendingSync, isTrue);
    });

    test('a board refresh keeps a queued mark', () async {
      // Arrange
      remote.markErrors.add(const NetworkException());
      await repository.markPaid('g1', 'pay1', method: PaymentMethod.cash, key: const IdempotencyKey('key-z'));
      remote.board = [PaymentModel.fromJson(paymentJson('pay1'))];

      // Act
      await repository.refreshPeriodPayments('g1', 'p1');

      // Assert
      final row = await db.paymentsDao.getById('pay1');
      expect(row?.status, 'paid');
      expect(row?.pendingSync, isTrue);
    });
  });

  test('getPayout caches the payout', () async {
    // Act
    final result = await repository.getPayout('g1', 'p1');

    // Assert
    expect(result.getRight().toNullable()?.amount, 2000000);
    final cached = (await repository.watchPayout('p1').first).getOrElse((_) => null);
    expect(cached?.recordedBy?.name, 'Bu Sari');
  });
}
