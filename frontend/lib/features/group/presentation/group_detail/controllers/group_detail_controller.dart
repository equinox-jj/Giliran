import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../payment/domain/entities/payment.dart';
import '../../../../payment/domain/entities/period.dart';
import '../../../../payment/domain/usecases/refresh_period_payments_usecase.dart';
import '../../../../payment/domain/usecases/refresh_periods_usecase.dart';
import '../../../../payment/domain/usecases/watch_period_payments_usecase.dart';
import '../../../../payment/domain/usecases/watch_periods_usecase.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/usecases/close_group_usecase.dart';
import '../../../domain/usecases/group_menu_actions_usecase.dart';
import '../../../domain/usecases/pick_hero_action_usecase.dart';
import '../../../domain/usecases/refresh_group_usecase.dart';
import '../../../domain/usecases/watch_group_usecase.dart';

part 'group_detail_controller.freezed.dart';
part 'group_detail_controller.g.dart';

/// The group detail frame (S20–S23): the cached group, its periods, my
/// payment in the current period, the hero action and the role-based menu.
@freezed
abstract class const GroupDetailState._() with _$GroupDetailState {
  const factory({
    GroupDetail? group,

    /// Every period by number, from the cache (empty until loaded).
    @Default(<Period>[]) List<Period> periods,

    /// The open (or last drawn) period the hero is about.
    Period? currentPeriod,

    /// My row on the current period's board, once it is cached.
    Payment? myPayment,
    @Default(HeroAction.none) HeroAction heroAction,
    @Default(<GroupMenuAction>[]) List<GroupMenuAction> menu,

    /// False until the first refresh finished or the cache had the group.
    @Default(false) bool loaded,

    /// The server says the group is gone or I'm no longer in it.
    @Default(false) bool notFound,
  }) = _GroupDetailState;

  /// Proofs waiting for review this period, from the period summary when
  /// it is cached, else from the group list.
  int get pendingCount => currentPeriod?.paymentSummary?.pendingReviewCount ?? group?.pendingReviewCount ?? 0;
}

/// Watches one cached group and its periods, refreshes them from the API
/// on open and on pull-to-refresh, and closes the group for the organizer.
@riverpod
class GroupDetailController() extends _$GroupDetailController {
  GroupDetail? _group;
  var _periods = const <Period>[];
  Payment? _myPayment;
  var _loaded = false;
  var _notFound = false;

  StreamSubscription<void>? _periodsSub;
  StreamSubscription<void>? _boardSub;
  String? _boardPeriodId;

  @override
  Stream<GroupDetailState> build(String groupId) {
    _cancel();
    ref.onDispose(_cancel);
    _periodsSub = ref.watch(watchPeriodsUseCaseProvider)(groupId).listen((result) {
      if (result case Right(:final value)) {
        _periods = value;
        _watchBoard();
        _emit();
      }
    });
    unawaited(Future.microtask(refresh));
    return ref.watch(watchGroupUseCaseProvider)(groupId).map((result) {
      switch (result) {
        case Left(:final value):
          throw value;
        case Right(:final value):
          _group = value;
          if (value != null) _loaded = true;
          _watchBoard();
          return _compose();
      }
    });
  }

  /// Fetches the group, its periods and the current board into the cache.
  /// Returns the group's failure, if any; a 404 marks the group as gone.
  Future<Failure?> refresh() async {
    final results = await Future.wait([
      ref.read(refreshGroupUseCaseProvider)(groupId),
      ref.read(refreshPeriodsUseCaseProvider)(groupId),
    ]);
    if (!ref.mounted) return results.first.getLeft().toNullable();
    final failure = results.first.getLeft().toNullable();
    _loaded = true;
    _notFound = failure is NotFoundFailure;
    final periodId = _currentPeriod()?.id;
    if (periodId != null) {
      await ref.read(refreshPeriodPaymentsUseCaseProvider)((groupId: groupId, periodId: periodId));
      if (!ref.mounted) return failure;
    }
    _emit();
    return failure;
  }

  /// Closes the group for good (organizer). Returns the failure, if any.
  Future<Failure?> close() async {
    final result = await ref.read(closeGroupUseCaseProvider)(groupId);
    return result.getLeft().toNullable();
  }

  void _emit() {
    if (ref.mounted && state.hasValue) state = AsyncData(_compose());
  }

  void _cancel() {
    unawaited(_periodsSub?.cancel());
    unawaited(_boardSub?.cancel());
    _periodsSub = null;
    _boardSub = null;
    _boardPeriodId = null;
  }

  /// Follows my row on the current period's board, switching when the
  /// current period changes.
  void _watchBoard() {
    final periodId = _currentPeriod()?.id;
    if (periodId == _boardPeriodId) return;
    unawaited(_boardSub?.cancel());
    _boardPeriodId = periodId;
    _myPayment = null;
    if (periodId == null) return;
    _boardSub = ref.read(watchPeriodPaymentsUseCaseProvider)(periodId).listen((result) {
      if (result case Right(:final value)) {
        _myPayment = value.where((p) => p.mine).firstOrNull;
        _emit();
      }
    });
  }

  Period? _currentPeriod() {
    final id = _group?.currentPeriodId;
    return _periods.where((p) => p.id == id).firstOrNull;
  }

  GroupDetailState _compose() {
    final group = _group;
    final period = _currentPeriod();
    final today = AppDate.jakartaToday(ref.read(clockProvider)());
    final draw = period?.drawDate ?? group?.nextDrawDate;
    final composed = GroupDetailState(
      group: group,
      periods: _periods,
      currentPeriod: period,
      myPayment: _myPayment,
      menu: ref.read(groupMenuActionsUseCaseProvider)((role: group?.myRole, status: group?.status)),
      loaded: _loaded,
      notFound: _notFound,
    );
    return composed.copyWith(
      heroAction: ref.read(pickHeroActionUseCaseProvider)((
        status: group?.status,
        role: group?.myRole,
        myPaymentStatus: _myPayment?.status ?? group?.myPaymentStatus,
        pendingCount: composed.pendingCount,
        drawDateReached: draw != null && !draw.isAfter(today),
        drawn: period?.isDrawn ?? false,
        payoutRecorded: period?.payoutRecorded ?? false,
      )),
    );
  }
}
