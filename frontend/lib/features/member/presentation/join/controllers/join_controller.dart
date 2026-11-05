import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../domain/entities/invite_preview.dart';
import '../../../domain/usecases/get_invite_preview_usecase.dart';
import '../../../domain/usecases/join_group_usecase.dart';

part 'join_controller.freezed.dart';
part 'join_controller.g.dart';

/// Join preview: the group behind the code and the join action.
@freezed
abstract class JoinState with _$JoinState {
  const factory({required InvitePreview preview, @Default(false) bool joining}) = _JoinState;
}

/// How a join attempt ended. [groupId] is where to go next.
typedef JoinOutcome = ({String? groupId, Failure? failure});

/// A bad or expired code won't fix itself, and the page offers "Coba lagi"
/// for the rest, so Riverpod's automatic retry is off.
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
class JoinController() extends _$JoinController {
  @override
  Future<JoinState> build(String code) async {
    final result = await ref.read(getInvitePreviewUseCaseProvider)(code);
    return switch (result) {
      Left(:final value) => throw value,
      Right(:final value) => JoinState(preview: value),
    };
  }

  /// Joins the group. An `already_member` answer still leads to the group.
  Future<JoinOutcome> join() async {
    final current = state.value;
    if (current == null || current.joining) return (groupId: null, failure: null);
    state = AsyncData(current.copyWith(joining: true));
    final result = await ref.read(joinGroupUseCaseProvider)(code);
    if (ref.mounted) state = AsyncData(current.copyWith(joining: false));
    final groupId = current.preview.groupId;
    return switch (result) {
      Right(:final value) => (groupId: value.groupId ?? groupId, failure: null),
      Left(value: ConflictFailure(code: ApiErrorCode.alreadyMember)) => (
        groupId: groupId,
        failure: null,
      ),
      Left(:final value) => (groupId: null, failure: value),
    };
  }
}
