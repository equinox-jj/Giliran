import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/group_list_filter.dart';
import '../../../domain/entities/group_summary.dart';
import '../../../domain/usecases/filter_groups_usecase.dart';
import '../../../domain/usecases/refresh_my_groups_usecase.dart';
import '../../../domain/usecases/watch_my_groups_usecase.dart';

part 'groups_controller.freezed.dart';
part 'groups_controller.g.dart';

/// The Groups list (S11) for one segment.
@freezed
abstract class GroupsState with _$GroupsState {
  const factory({
    @Default(<GroupSummary>[]) List<GroupSummary> groups,

    /// [groups] narrowed by [chip].
    @Default(<GroupSummary>[]) List<GroupSummary> visibleGroups,
    @Default(GroupChipFilter.all) GroupChipFilter chip,

    /// False until the first refresh finished or the cache had groups.
    @Default(false) bool loaded,
  }) = _GroupsState;
}

/// Watches the cached groups for a segment (Aktif or Selesai), refreshes
/// them on start and on pull-to-refresh, and applies the role chip locally.
@riverpod
class GroupsController() extends _$GroupsController {
  var _groups = const <GroupSummary>[];
  var _chip = GroupChipFilter.all;
  var _loaded = false;

  @override
  Stream<GroupsState> build(GroupListFilter filter) {
    unawaited(Future.microtask(refresh));
    return ref.watch(watchMyGroupsUseCaseProvider)(filter).map((result) {
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

  /// Fetches the segment's groups into the cache; returns the failure, if
  /// any, while cached data stays on screen.
  Future<Failure?> refresh() async {
    final result = await ref.read(refreshMyGroupsUseCaseProvider)(filter);
    if (!ref.mounted) return result.getLeft().toNullable();
    _loaded = true;
    if (state.hasValue) state = AsyncData(_compose());
    return result.getLeft().toNullable();
  }

  /// Selects [chip]; selecting the active chip again clears it.
  void toggleChip(GroupChipFilter chip) {
    _chip = _chip == chip ? GroupChipFilter.all : chip;
    if (state.hasValue) state = AsyncData(_compose());
  }

  GroupsState _compose() => GroupsState(
    groups: _groups,
    visibleGroups: ref.read(filterGroupsUseCaseProvider)((groups: _groups, filter: _chip)),
    chip: _chip,
    loaded: _loaded,
  );
}
