import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../domain/usecases/request_leave_usecase.dart';
import '../../members_tab/controllers/members_tab_controller.dart';

part 'leave_controller.freezed.dart';
part 'leave_controller.g.dart';

/// The leave request sheet while it sends, and its last failure.
@freezed
abstract class LeaveState with _$LeaveState {
  const factory({@Default(false) bool sending, Failure? failure}) = _LeaveState;
}

/// Sends the caller's leave request; the Anggota tab then shows it pending.
@riverpod
class LeaveController() extends _$LeaveController {
  @override
  LeaveState build(String groupId) => const LeaveState();

  /// Sends the request. True when it was created.
  Future<bool> send(String? reason) async {
    if (state.sending) return false;
    state = const LeaveState(sending: true);
    final result = await ref.read(requestLeaveUseCaseProvider)((groupId: groupId, reason: reason));
    if (!ref.mounted) return result.isRight();
    state = LeaveState(failure: result.getLeft().toNullable());
    if (result.isRight()) ref.invalidate(membersTabControllerProvider(groupId));
    return result.isRight();
  }
}
