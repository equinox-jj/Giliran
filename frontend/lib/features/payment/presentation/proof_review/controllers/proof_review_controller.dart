import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/idempotency.dart';
import '../../../../../core/utils/enums/payment_status.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/approve_payment_usecase.dart';
import '../../../domain/usecases/get_payment_detail_usecase.dart';
import '../../../domain/usecases/reject_payment_usecase.dart';
import '../../../domain/usecases/sort_payment_board_usecase.dart';
import '../../../domain/usecases/watch_period_payments_usecase.dart';

part 'proof_review_controller.freezed.dart';
part 'proof_review_controller.g.dart';

/// Proof review, or the payer's own proof viewer: the payments to
/// swipe through, each one's detail (with signed proof URLs) once loaded.
@freezed
abstract class const ProofReviewState._() with _$ProofReviewState {
  const factory({
    /// Payment ids in swipe order: the opened one plus, for managers, the
    /// period's other pending proofs by slot.
    @Default(<String>[]) List<String> queue,
    @Default(0) int index,
    @Default(<String, Payment>{}) Map<String, Payment> details,

    /// Why the current payment could not be loaded.
    Failure? loadFailure,

    /// An approve or reject is in flight.
    @Default(false) bool busy,
  }) = _ProofReviewState;

  String? get currentId => queue.isEmpty ? null : queue[index.clamp(0, queue.length - 1)];

  Payment? get current => details[currentId];

  bool get canReview => current?.status == PaymentStatus.pendingReview && !busy;
}

/// Loads a payment's proofs and approves or rejects them. Each approve or
/// reject of one payment keeps its [IdempotencyKey] until it succeeds, so a
/// retry after a timeout is applied at most once.
@riverpod
class ProofReviewController() extends _$ProofReviewController {
  final _keys = <String, IdempotencyKey>{};

  @override
  ProofReviewState build(String groupId, String paymentId) {
    unawaited(Future.microtask(() => _load(paymentId)));
    return ProofReviewState(queue: [paymentId]);
  }

  /// Adds the period's other pending proofs to the swipe queue (managers).
  Future<void> loadQueue() async {
    final periodId = state.details[paymentId]?.periodId ?? await _periodId();
    if (periodId == null || !ref.mounted) return;
    final board = await ref.read(watchPeriodPaymentsUseCaseProvider)(periodId).first;
    if (!ref.mounted) return;
    final pending = ref.read(sortPaymentBoardUseCaseProvider)((
      payments: board.getOrElse((_) => const []),
      filter: PaymentBoardFilter.pendingReview,
    ));
    final ids = [for (final p in pending) ?p.id];
    if (!ids.contains(paymentId)) return;
    state = state.copyWith(queue: ids, index: ids.indexOf(paymentId));
  }

  /// Shows the payment at [index] in the queue, loading it if needed.
  void select(int index) {
    state = state.copyWith(index: index, loadFailure: null);
    final id = state.currentId;
    if (id != null && !state.details.containsKey(id)) unawaited(_load(id));
  }

  /// Reloads the current payment (after `payment_already_reviewed`).
  Future<void> reload() async {
    final id = state.currentId;
    if (id != null) await _load(id);
  }

  Future<Failure?> approve() async {
    final id = state.currentId;
    if (id == null || !state.canReview) return null;
    final key = _keys.putIfAbsent('approve:$id', IdempotencyKey.generate);
    return _write(
      id,
      'approve:$id',
      ref.read(approvePaymentUseCaseProvider)((groupId: groupId, paymentId: id, key: key)),
    );
  }

  Future<Failure?> reject(String reason) async {
    final id = state.currentId;
    if (id == null || !state.canReview) return null;
    // A different reason is a different request body, so it needs its own key.
    final slot = 'reject:$id:${reason.trim()}';
    final key = _keys.putIfAbsent(slot, IdempotencyKey.generate);
    return _write(
      id,
      slot,
      ref.read(rejectPaymentUseCaseProvider)((groupId: groupId, paymentId: id, reason: reason, key: key)),
    );
  }

  /// Drops the reviewed payment from the queue and moves to the next one.
  /// Returns false when nothing is left to review.
  bool advance() {
    final id = state.currentId;
    final queue = [
      for (final q in state.queue)
        if (q != id) q,
    ];
    if (queue.isEmpty) return false;
    state = state.copyWith(queue: queue, index: state.index.clamp(0, queue.length - 1));
    select(state.index);
    return true;
  }

  Future<Failure?> _write(String id, String slot, Future<Either<Failure, Payment>> call) async {
    state = state.copyWith(busy: true);
    final result = await call;
    if (!ref.mounted) return result.getLeft().toNullable();
    switch (result) {
      case Left(:final value):
        state = state.copyWith(busy: false);
        return value;
      case Right(:final value):
        _keys.remove(slot);
        final merged = value.copyWith(proofs: value.proofs ?? state.details[id]?.proofs);
        state = state.copyWith(busy: false, details: {...state.details, id: merged});
        return null;
    }
  }

  Future<String?> _periodId() async {
    await _load(paymentId);
    return state.details[paymentId]?.periodId;
  }

  Future<void> _load(String id) async {
    final result = await ref.read(getPaymentDetailUseCaseProvider)((groupId: groupId, paymentId: id));
    if (!ref.mounted) return;
    switch (result) {
      case Left(:final value):
        if (state.currentId == id) state = state.copyWith(loadFailure: value);
      case Right(:final value):
        state = state.copyWith(
          details: {...state.details, id: value},
          loadFailure: state.currentId == id ? null : state.loadFailure,
        );
    }
  }
}
