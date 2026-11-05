import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/refresh_period_payments_usecase.dart';
import '../../../domain/usecases/sort_payment_board_usecase.dart';
import '../../../domain/usecases/watch_period_payments_usecase.dart';

part 'payments_tab_controller.freezed.dart';
part 'payments_tab_controller.g.dart';

/// The Pembayaran tab for one period: the cached board, the rows
/// to show under the selected filter, and whether a refresh failed.
@freezed
abstract class PaymentsTabState with _$PaymentsTabState {
  const factory({
    /// Every row on the board, by slot.
    @Default(<Payment>[]) List<Payment> all,

    /// [all] filtered and ordered (my row first).
    @Default(<Payment>[]) List<Payment> rows,
    @Default(PaymentBoardFilter.all) PaymentBoardFilter filter,

    /// The last refresh failed (rows may still come from the cache).
    @Default(false) bool failed,

    /// False until the first refresh finished.
    @Default(false) bool loaded,
  }) = _PaymentsTabState;
}

/// Watches a period's cached payment board and refreshes it from the API
/// on open and on [refresh] (server wins).
@riverpod
class PaymentsTabController() extends _$PaymentsTabController {
  var _all = const <Payment>[];
  var _filter = PaymentBoardFilter.all;
  var _failed = false;
  var _loaded = false;

  @override
  Stream<PaymentsTabState> build(String groupId, String periodId) {
    unawaited(Future.microtask(refresh));
    return ref.watch(watchPeriodPaymentsUseCaseProvider)(periodId).map((result) {
      switch (result) {
        case Left(:final value):
          throw value;
        case Right(:final value):
          _all = value;
          return _compose();
      }
    });
  }

  /// Fetches the board into the cache. Returns the failure, if any.
  Future<Failure?> refresh() async {
    final result = await ref.read(refreshPeriodPaymentsUseCaseProvider)((groupId: groupId, periodId: periodId));
    if (!ref.mounted) return result.getLeft().toNullable();
    _failed = result.isLeft();
    _loaded = true;
    if (state.hasValue) state = AsyncData(_compose());
    return result.getLeft().toNullable();
  }

  void setFilter(PaymentBoardFilter filter) {
    _filter = filter;
    if (state.hasValue) state = AsyncData(_compose());
  }

  PaymentsTabState _compose() => PaymentsTabState(
    all: _all,
    rows: ref.read(sortPaymentBoardUseCaseProvider)((payments: _all, filter: _filter)),
    filter: _filter,
    failed: _failed,
    loaded: _loaded,
  );
}
