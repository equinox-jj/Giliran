import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/enums/leave_request_status.dart';
import '../../../domain/entities/leave_request.dart';
import '../../../domain/entities/obligation.dart';
import '../../../domain/usecases/approve_leave_usecase.dart';
import '../../../domain/usecases/get_leave_requests_usecase.dart';
import '../../../domain/usecases/get_obligations_usecase.dart';
import '../../../domain/usecases/reject_leave_usecase.dart';
import '../../members_tab/controllers/members_tab_controller.dart';

part 'leave_requests_controller.freezed.dart';
part 'leave_requests_controller.g.dart';

/// Leave requests review: pending requests, newest first, and what
/// past winners among them still owe.
@freezed
abstract class LeaveRequestsState with _$LeaveRequestsState {
  const factory({
    @Default(<LeaveRequest>[]) List<LeaveRequest> requests,

    /// Obligations by member id, for the inline winner warning.
    @Default(<String, Obligation>{}) Map<String, Obligation> obligations,

    /// The request being approved or rejected.
    String? busyId,
  }) = _LeaveRequestsState;
}

/// The page offers "Coba lagi", so Riverpod's automatic retry is off.
Duration? _noRetry(int retryCount, Object error) => null;

/// Loads the pending requests and approves or rejects them (organizers).
@Riverpod(retry: _noRetry)
class LeaveRequestsController() extends _$LeaveRequestsController {
  @override
  Future<LeaveRequestsState> build(String groupId) async {
    final (requests, obligations) = await (
      ref.read(getLeaveRequestsUseCaseProvider)((groupId: groupId, status: LeaveRequestStatus.pending)),
      ref.read(getObligationsUseCaseProvider)(groupId),
    ).wait;
    if (requests case Left(:final value)) throw value;
    return LeaveRequestsState(
      requests: requests.getOrElse((_) => const []),
      obligations: {
        for (final o in obligations.getOrElse((_) => const [])) ?o.memberId: o,
      },
    );
  }

  /// Approves request [id]. Returns the failure, if any.
  Future<Failure?> approve(String id) =>
      _review(id, () => ref.read(approveLeaveUseCaseProvider)((groupId: groupId, requestId: id)));

  /// Rejects request [id] with an optional [reason]. Returns the failure, if
  /// any.
  Future<Failure?> reject(String id, String? reason) => _review(
    id,
    () => ref.read(rejectLeaveUseCaseProvider)((groupId: groupId, requestId: id, reason: reason)),
  );

  Future<Failure?> _review(String id, Future<Either<Failure, LeaveRequest>> Function() call) async {
    final current = state.value;
    if (current == null || current.busyId != null) return null;
    state = AsyncData(current.copyWith(busyId: id));
    final result = await call();
    if (!ref.mounted) return result.getLeft().toNullable();
    state = AsyncData(
      current.copyWith(
        busyId: null,
        requests: result.isRight() ? [...current.requests.where((r) => r.id != id)] : current.requests,
      ),
    );
    if (result.isRight()) ref.invalidate(membersTabControllerProvider(groupId));
    return result.getLeft().toNullable();
  }
}
