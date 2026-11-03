import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/enums/group_list_filter.dart';
import '../../../../group/domain/entities/group_summary.dart';
import '../../../../group/domain/usecases/filter_groups_usecase.dart';
import '../../../../group/domain/usecases/refresh_my_groups_usecase.dart';
import '../../../../group/domain/usecases/watch_my_groups_usecase.dart';
import '../../../domain/entities/agenda_day.dart';
import '../../../domain/entities/next_action.dart';
import '../../../domain/usecases/build_agenda_usecase.dart';
import '../../../domain/usecases/pick_next_action_usecase.dart';

part 'home_controller.freezed.dart';
part 'home_controller.g.dart';

/// Everything Beranda (S10) shows, derived from the cached active groups.
@freezed
abstract class HomeState with _$HomeState {
  const factory({
    @Default(<GroupSummary>[]) List<GroupSummary> groups,

    /// [groups] narrowed by [filter], for the carousel.
    @Default(<GroupSummary>[]) List<GroupSummary> visibleGroups,
    @Default(GroupChipFilter.all) GroupChipFilter filter,
    NextAction? nextAction,
    @Default(<AgendaDay>[]) List<AgendaDay> agenda,

    /// My unpaid or rejected dues this period, for the headline.
    @Default(0) int openDues,

    /// False until the first refresh finished or the cache had groups, so an
    /// empty first frame shows skeletons rather than the empty state.
    @Default(false) bool loaded,
    DateTime? lastSyncedAt,
  }) = _HomeState;
}

/// Watches the cached active groups, refreshes them from the API on start
/// and on pull-to-refresh, and derives the hero, agenda and headline through
/// the home usecases.
@riverpod
class HomeController() extends _$HomeController {
  var _groups = const <GroupSummary>[];
  var _filter = GroupChipFilter.all;
  var _loaded = false;
  DateTime? _lastSyncedAt;

  @override
  Stream<HomeState> build() {
    unawaited(Future.microtask(refresh));
    return ref.watch(watchMyGroupsUseCaseProvider)(GroupListFilter.active).map((result) {
      switch (result) {
        case Left(:final value):
          throw value;
        case Right(:final value):
          _groups = value;
          if (value.isNotEmpty) _loaded = true;
          return _compose();
      }
    });
  }

  /// Fetches the groups into the cache. Returns the failure, if any, so the
  /// page can show it; cached data stays on screen.
  Future<Failure?> refresh() async {
    final result = await ref.read(refreshMyGroupsUseCaseProvider)(GroupListFilter.active);
    if (!ref.mounted) return result.getLeft().toNullable();
    _loaded = true;
    if (result.isRight()) _lastSyncedAt = ref.read(clockProvider)();
    if (state.hasValue) state = AsyncData(_compose());
    return result.getLeft().toNullable();
  }

  void setFilter(GroupChipFilter filter) {
    _filter = filter;
    if (state.hasValue) state = AsyncData(_compose());
  }

  HomeState _compose() {
    final now = ref.read(clockProvider)();
    final filter = ref.read(filterGroupsUseCaseProvider);
    return HomeState(
      groups: _groups,
      visibleGroups: filter((groups: _groups, filter: _filter)),
      filter: _filter,
      nextAction: ref.read(pickNextActionUseCaseProvider)((
        groups: _groups,
        now: now,
        payoutsToConfirm: const {},
      )),
      agenda: ref.read(buildAgendaUseCaseProvider)((groups: _groups, now: now)),
      openDues: filter((groups: _groups, filter: GroupChipFilter.unpaid)).length,
      loaded: _loaded,
      lastSyncedAt: _lastSyncedAt,
    );
  }
}
