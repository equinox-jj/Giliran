import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/utils/enums/leave_request_status.dart';
import '../../../domain/entities/obligation.dart';
import '../../../domain/usecases/get_leave_requests_usecase.dart';
import '../../../domain/usecases/get_obligations_usecase.dart';

part 'members_tab_controller.freezed.dart';
part 'members_tab_controller.g.dart';

/// The live parts of the Anggota tab (S22). The members themselves come
/// from `MembersController`.
@freezed
abstract class MembersTabState with _$MembersTabState {
  const factory({
    /// Past winners, overdue first; empty while nobody has won.
    @Default(<Obligation>[]) List<Obligation> obligations,

    /// Pending leave requests (managers see everyone's, members their own).
    @Default(0) int pendingLeaveCount,
  }) = _MembersTabState;
}

/// The tab shows its own "Coba lagi", so Riverpod's automatic retry is off.
Duration? _noRetry(int retryCount, Object error) => null;

/// Loads obligations and pending leave requests for the Anggota tab, again
/// on [refresh] and after a leave request or review.
@Riverpod(retry: _noRetry)
class MembersTabController() extends _$MembersTabController {
  @override
  Future<MembersTabState> build(String groupId) async {
    final (obligations, requests) = await (
      ref.read(getObligationsUseCaseProvider)(groupId),
      ref.read(getLeaveRequestsUseCaseProvider)((groupId: groupId, status: LeaveRequestStatus.pending)),
    ).wait;
    if (obligations case Left(:final value)) throw value;
    return MembersTabState(
      obligations: obligations.getOrElse((_) => const []),
      // Leave requests are secondary; the tab still works without them.
      pendingLeaveCount: requests.getOrElse((_) => const []).length,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
