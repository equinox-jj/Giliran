import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/usecases/close_group_usecase.dart';
import '../../../domain/usecases/group_menu_actions_usecase.dart';
import '../../../domain/usecases/pick_hero_action_usecase.dart';
import '../../../domain/usecases/refresh_group_usecase.dart';
import '../../../domain/usecases/watch_group_usecase.dart';

part 'group_detail_controller.freezed.dart';
part 'group_detail_controller.g.dart';

/// The group detail frame (S20–S23): the cached group, its hero action and
/// its role-based menu.
@freezed
abstract class GroupDetailState with _$GroupDetailState {
  const factory({
    GroupDetail? group,
    @Default(HeroAction.none) HeroAction heroAction,
    @Default(<GroupMenuAction>[]) List<GroupMenuAction> menu,

    /// False until the first refresh finished or the cache had the group.
    @Default(false) bool loaded,

    /// The server says the group is gone or I'm no longer in it.
    @Default(false) bool notFound,
  }) = _GroupDetailState;
}

/// Watches one cached group, refreshes it from the API on open and on
/// pull-to-refresh, and closes it for the organizer.
@riverpod
class GroupDetailController() extends _$GroupDetailController {
  GroupDetail? _group;
  var _loaded = false;
  var _notFound = false;

  @override
  Stream<GroupDetailState> build(String groupId) {
    unawaited(Future.microtask(refresh));
    return ref.watch(watchGroupUseCaseProvider)(groupId).map((result) {
      switch (result) {
        case Left(:final value):
          throw value;
        case Right(:final value):
          _group = value;
          if (value != null) _loaded = true;
          return _compose();
      }
    });
  }

  /// Fetches the group into the cache. Returns the failure, if any; a 404
  /// marks the group as gone.
  Future<Failure?> refresh() async {
    final result = await ref.read(refreshGroupUseCaseProvider)(groupId);
    if (!ref.mounted) return result.getLeft().toNullable();
    _loaded = true;
    _notFound = result.getLeft().toNullable() is NotFoundFailure;
    if (state.hasValue) state = AsyncData(_compose());
    return result.getLeft().toNullable();
  }

  /// Closes the group for good (organizer). Returns the failure, if any.
  Future<Failure?> close() async {
    final result = await ref.read(closeGroupUseCaseProvider)(groupId);
    return result.getLeft().toNullable();
  }

  GroupDetailState _compose() {
    final group = _group;
    final today = AppDate.jakartaToday(ref.read(clockProvider)());
    final draw = group?.nextDrawDate;
    return GroupDetailState(
      group: group,
      heroAction: ref.read(pickHeroActionUseCaseProvider)((
        status: group?.status,
        role: group?.myRole,
        myPaymentStatus: group?.myPaymentStatus,
        pendingCount: group?.pendingReviewCount ?? 0,
        drawDateReached: draw != null && !draw.isAfter(today),
        // Period draw and payout state arrive with the periods (Tasks 4.1, 5.x).
        drawn: false,
        payoutRecorded: false,
      )),
      menu: ref.read(groupMenuActionsUseCaseProvider)((role: group?.myRole, status: group?.status)),
      loaded: _loaded,
      notFound: _notFound,
    );
  }
}
