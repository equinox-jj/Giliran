import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../group/domain/entities/group.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/readiness.dart';
import '../../../domain/usecases/build_readiness_usecase.dart';
import '../../../domain/usecases/start_group_usecase.dart';
import '../../shared/controllers/members_controller.dart';

part 'start_group_controller.freezed.dart';
part 'start_group_controller.g.dart';

/// Start group (S18): the group, its readiness checklist and the start
/// action.
@freezed
abstract class const StartGroupState._() with _$StartGroupState {
  const factory({
    GroupDetail? group,
    @Default(<ReadinessItem>[]) List<ReadinessItem> items,

    /// The item a `409` from `POST /start` named.
    ReadinessKind? highlight,
    @Default(false) bool starting,
  }) = _StartGroupState;

  int get missing => items.where((i) => !i.done).length;
}

/// Builds the checklist from the cached group and members (both refreshed
/// by their own controllers) and starts the group.
@riverpod
class StartGroupController() extends _$StartGroupController {
  ReadinessKind? _highlight;
  var _starting = false;

  @override
  StartGroupState build(String groupId) {
    final group = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group));
    final members = ref.watch(membersControllerProvider(groupId).select((s) => s.value ?? const <Member>[]));
    return StartGroupState(
      group: group,
      items: group == null ? const [] : ref.read(buildReadinessUseCaseProvider)((group: group, members: members)),
      highlight: _highlight,
      starting: _starting,
    );
  }

  /// Starts the group. A `409` names the checklist item to highlight.
  /// Returns the failure, if any.
  Future<Failure?> start() async {
    if (_starting) return null;
    _starting = true;
    _highlight = null;
    state = state.copyWith(starting: true, highlight: null);
    final result = await ref.read(startGroupUseCaseProvider)(groupId);
    if (!ref.mounted) return result.getLeft().toNullable();
    _starting = false;
    final failure = result.getLeft().toNullable();
    _highlight = BuildReadinessUseCase.kindFor(failure?.apiCode);
    state = state.copyWith(starting: false, highlight: _highlight);
    if (result is Right) {
      // The detail page reads the now active group from the cache.
      ref.invalidate(membersControllerProvider(groupId));
    }
    return failure;
  }
}
