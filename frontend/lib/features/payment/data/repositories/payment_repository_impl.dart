import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/base_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/enums/payment_method.dart';
import '../../../../core/utils/logger/app_logger.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/period.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasource/model/payment_model.dart';
import '../datasource/payment_local_data_source.dart';
import '../datasource/payment_local_data_source_impl.dart';
import '../datasource/payment_remote_data_source.dart';
import '../datasource/payment_remote_data_source_impl.dart';
import '../mappers/payment_mapper.dart';

part 'payment_repository_impl.g.dart';

class PaymentRepositoryImpl(
  final PaymentRemoteDataSource _remote,
  final PaymentLocalDataSource _local,
  final DateTime Function() _now,
) with BaseRepository implements PaymentRepository {
  static const _tag = 'payment';

  @override
  Stream<Either<Failure, List<Period>>> watchPeriods(String groupId) =>
      safeStream(_local.watchPeriods(groupId).map((rows) => [for (final r in rows) r.toEntity()]));

  @override
  Future<Either<Failure, Unit>> refreshPeriods(String groupId) => safeCall(() async {
    await _savePeriods(groupId);
    return unit;
  });

  @override
  Stream<Either<Failure, List<Payment>>> watchPeriodPayments(String periodId) =>
      safeStream(_local.watchPayments(periodId).map((rows) => [for (final r in rows) r.toEntity()]));

  @override
  Future<Either<Failure, Unit>> refreshPeriodPayments(String groupId, String periodId) => safeCall(() async {
    await _saveBoard(groupId, periodId);
    return unit;
  });

  @override
  Future<Either<Failure, Payment>> getPaymentDetail(String groupId, String paymentId) => safeCall(() async {
    final model = await _remote.getPayment(groupId, paymentId);
    await _local.upsertPayments([model.toCompanion(groupId)]);
    return model.toEntity(groupId: groupId);
  });

  @override
  Future<Either<Failure, Payment>> uploadProof(
    String groupId,
    String paymentId,
    String path, {
    required IdempotencyKey key,
    void Function(double progress)? onProgress,
  }) => safeCall(
    () async => _afterWrite(
      groupId,
      await _remote.uploadProof(groupId, paymentId, path, key: key, onProgress: onProgress),
    ),
  );

  @override
  Future<Either<Failure, Payment>> approvePayment(String groupId, String paymentId, {required IdempotencyKey key}) =>
      safeCall(() async => _afterWrite(groupId, await _remote.approvePayment(groupId, paymentId, key: key)));

  @override
  Future<Either<Failure, Payment>> rejectPayment(
    String groupId,
    String paymentId, {
    required String reason,
    required IdempotencyKey key,
  }) => safeCall(
    () async => _afterWrite(groupId, await _remote.rejectPayment(groupId, paymentId, reason: reason, key: key)),
  );

  @override
  Future<Either<Failure, Payment>> markPaid(
    String groupId,
    String paymentId, {
    required PaymentMethod method,
    String? note,
    required IdempotencyKey key,
  }) => safeCall(() async {
    final PaymentModel model;
    try {
      model = await _remote.markPaid(groupId, paymentId, method: method.apiValue, note: note, key: key);
    } on NetworkException {
      return _queueMark(paymentId, method: method, note: note, key: key);
    } on TimeoutException {
      // The server may have recorded it; the stored key makes the retry a
      // replay instead of a second mark.
      return _queueMark(paymentId, method: method, note: note, key: key);
    }
    return _afterWrite(groupId, model);
  });

  @override
  Future<Either<Failure, SyncReport>> syncPendingPayments() => safeCall(() async {
    var synced = 0;
    final rejected = <Payment>[];
    for (final row in await _local.getPendingPayments()) {
      final key = row.pendingIdempotencyKey;
      if (key == null) {
        await _local.clearPending(row.id);
        continue;
      }
      try {
        final model = await _sendQueuedMark(row, IdempotencyKey(key));
        await _local.upsertPayments([model.toCompanion(row.groupId)]);
        synced++;
      } on NetworkException {
        break;
      } on TimeoutException {
        break;
      } on ApiException catch (e) {
        if (e is ServerException || e is TooManyRequestsException || e is UnauthorizedException) {
          // Not the mark's fault; try again on the next sync.
          continue;
        }
        // The server refused the mark (another manager recorded it, the
        // payment changed): drop it and restore the server's row.
        AppLogger.w('Offline mark rejected: ${e.code.apiValue}', tag: _tag);
        await _local.clearPending(row.id);
        var restored = row.toEntity().copyWith(pendingSync: false);
        await _quietly(() async {
          final model = await _remote.getPayment(row.groupId, row.id);
          await _local.upsertPayments([model.toCompanion(row.groupId)]);
          restored = model.toEntity(groupId: row.groupId);
        });
        rejected.add(restored);
      }
    }
    return SyncReport(synced: synced, rejected: rejected);
  });

  @override
  Stream<Either<Failure, Payout?>> watchPayout(String periodId) =>
      safeStream(_local.watchPayout(periodId).map((row) => row?.toEntity()));

  @override
  Future<Either<Failure, Payout>> getPayout(String groupId, String periodId) => safeCall(() async {
    final model = await _remote.getPayout(groupId, periodId);
    await _local.upsertPayout(model.toCompanion(groupId));
    return model.toEntity();
  });

  @override
  Future<Either<Failure, Payout>> recordPayout(
    String groupId,
    String periodId, {
    String? proofPath,
    String? note,
    required IdempotencyKey key,
  }) => safeCall(() async {
    final model = await _remote.recordPayout(groupId, periodId, proofPath: proofPath, note: note, key: key);
    await _local.upsertPayout(model.toCompanion(groupId));
    // The period closes and the next one opens.
    await _quietly(() => _savePeriods(groupId));
    return model.toEntity();
  });

  @override
  Future<Either<Failure, Payout>> confirmPayout(String groupId, String periodId, {required IdempotencyKey key}) =>
      safeCall(() async {
        final model = await _remote.confirmPayout(groupId, periodId, key: key);
        await _local.upsertPayout(model.toCompanion(groupId));
        await _quietly(() => _savePeriods(groupId));
        return model.toEntity();
      });

  /// Sends a queued mark with the time the money changed hands. If the
  /// server refuses that time (a phone clock far off), the mark is sent again
  /// without it rather than dropped; a refused request stores nothing, so the
  /// same key still applies.
  Future<PaymentModel> _sendQueuedMark(PaymentRow row, IdempotencyKey key) async {
    Future<PaymentModel> send({DateTime? paidAt}) => _remote.markPaid(
      row.groupId,
      row.id,
      method: row.method ?? PaymentMethod.cash.apiValue,
      note: row.note,
      paidAt: paidAt,
      key: key,
    );
    try {
      return await send(paidAt: row.paidAt);
    } on ValidationException catch (e) {
      if (!e.fieldErrors.any((f) => f.field == 'paid_at')) rethrow;
      AppLogger.w('Queued paid_at refused, sending without it', tag: _tag);
      return send();
    }
  }

  Future<void> _savePeriods(String groupId) async {
    final periods = await _remote.listPeriods(groupId);
    await _local.upsertPeriods([for (final p in periods) p.toCompanion(groupId)]);
  }

  Future<void> _saveBoard(String groupId, String periodId) async {
    final board = await _remote.getPaymentBoard(groupId, periodId);
    await _local.replacePayments(periodId, [for (final p in board.payments) p.toCompanion(groupId)]);
    final summary = board.summary;
    if (summary != null) await _local.updatePeriodSummary(periodId, summary.toPeriodCompanion());
  }

  /// Caches the server's row after a payment write, then refreshes the
  /// board so the summary, the hero and the strip catch up.
  Future<Payment> _afterWrite(String groupId, PaymentModel model) async {
    await _local.upsertPayments([model.toCompanion(groupId)]);
    final periodId = model.periodId;
    if (periodId != null) await _quietly(() => _saveBoard(groupId, periodId));
    return model.toEntity(groupId: groupId);
  }

  Future<Payment> _queueMark(
    String paymentId, {
    required PaymentMethod method,
    String? note,
    required IdempotencyKey key,
  }) async {
    await _local.markPendingPaid(
      paymentId,
      method: method.apiValue,
      idempotencyKey: key.value,
      paidAt: _now().toUtc(),
      note: note,
    );
    final row = await _local.getPayment(paymentId);
    if (row == null) throw const CacheException('Queued payment is not cached');
    return row.toEntity();
  }

  /// Runs a cache follow-up after a write that already succeeded on the
  /// server. Its failure must not report the write as failed.
  Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } on AppException catch (e, st) {
      AppLogger.w('Cache follow-up failed', tag: _tag, error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
PaymentRepository paymentRepository(Ref ref) => PaymentRepositoryImpl(
  ref.watch(paymentRemoteDataSourceProvider),
  ref.watch(paymentLocalDataSourceProvider),
  ref.watch(clockProvider),
);
